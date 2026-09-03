require "archive_hook/version"

module ArchiveHook
  # Identifiers are interpolated straight into SQL, so anything that needs
  # quoting -- a column called "default", "order" or "group", a table name that
  # collides with a keyword -- has to be quoted or Postgres rejects the
  # statement with a syntax error.
  module Quoting
    private

    def quote_columns(column_names)
      column_names.map { |name| connection.quote_column_name(name) }.join(",")
    end

    def quote_table(name)
      connection.quote_table_name(name)
    end

    def connection
      ActiveRecord::Base.connection
    end
  end

  class ScopeArchiver
    include Quoting

    def initialize(dependencies: {})
      @dependencies = dependencies
    end

    def call(scope)
      parent = scope.model
      parent_id_groups = scope.in_batches.map { |relation| relation.pluck(:id) }
      return if parent_id_groups.empty?

      archive_children(parent, parent_id_groups)
      parent_id_groups.each do |parent_ids|
        archive_by_scope(parent.unscoped.where(id: parent_ids))
      end
    end

    private

    def archive_children(parent, parent_id_groups)
      return unless @dependencies[parent] && @dependencies[parent][:children].present?

      @dependencies[parent][:children].each do |child|
        parent_id_groups.each do |parent_ids|
          call(child.unscoped.where(parent.to_s.foreign_key => parent_ids))
        end
      end
    end

    def archive_by_scope(scope)
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute(Arel.sql(archive_records_sql(scope)))
        scope.delete_all
      end
    end

    def archive_records_sql(scope)
      attributes_list = quote_columns(scope.column_names)
      <<-SQL
        INSERT INTO #{quote_table("#{scope.table_name}_archive")} (#{attributes_list})
        #{scope.select(attributes_list).to_sql}
      SQL
    end
  end

  class ScopeRestorer
    include Quoting

    def initialize(dependencies: {})
      @dependencies = dependencies
    end

    def call(scope)
      parent = scope.model
      table_name = "#{quote_table("#{scope.table_name}_archive")} as #{quote_table(scope.table_name)}"
      parent_id_groups = scope.from(table_name).in_batches.map { |relation| relation.pluck(:id) }
      parent_id_groups.each do |parent_ids|
        restore_by_ids(parent, parent_ids)
      end
      restore_children(parent, parent_id_groups)
    end

    private

    def restore_children(parent, parent_id_groups)
      return unless @dependencies[parent] && @dependencies[parent][:children].present?

      @dependencies[parent][:children].each do |child|
        if parent_id_groups.present?
          parent_id_groups.each do |parent_ids|
            call(child.unscoped.where(parent.to_s.foreign_key => parent_ids))
          end
        else
          call(child.none)
        end
      end
    end

    def restore_by_ids(model, ids)
      ActiveRecord::Base.transaction do
        connection.execute(Arel.sql(restore_records_sql(model, ids)))
        connection.execute(Arel.sql <<-SQL
          DELETE FROM #{quote_table("#{model.table_name}_archive")}
          WHERE #{connection.quote_column_name(model.primary_key)} IN (#{ids.join(', ')})
        SQL
        )
      end
    end

    def restore_records_sql(model, ids)
      attributes_list = quote_columns(model.column_names)
      <<-SQL
        INSERT INTO #{quote_table(model.table_name)} (#{attributes_list})
        SELECT #{attributes_list} FROM #{quote_table("#{model.table_name}_archive")}
        WHERE #{connection.quote_column_name(model.primary_key)} IN (#{ids.join(', ')})
      SQL
    end
  end

  class << self
    def archive(root, archive_date, dependencies)
      column = dependencies[root] && dependencies[root][:column] || :created_at
      quoted_column = ActiveRecord::Base.connection.quote_column_name(column)
      base_scope = root.where("#{quoted_column} < ?", archive_date)
      ScopeArchiver.new(dependencies: dependencies).call(base_scope)
    end

    def archive_scope(scope, dependencies = {})
      ScopeArchiver.new(dependencies: dependencies).call(scope)
    end

    def restore_scope(scope, dependencies = {})
      ScopeRestorer.new(dependencies: dependencies).call(scope)
    end
  end
end
