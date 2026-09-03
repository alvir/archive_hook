# frozen_string_literal: true

class Create<%= archive_table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def up
    # Quoted at run time so a mixed-case table name survives Postgres folding
    # unquoted identifiers to lower case, and so a name that collides with a
    # reserved word still parses.
    execute(
      "CREATE TABLE #{connection.quote_table_name('<%= archive_table_name %>')} " \
      "(LIKE #{connection.quote_table_name('<%= table_name %>')})"
    )
  end

  def down
    drop_table :<%= archive_table_name %>
  end
end
