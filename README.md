# ArchiveHook

`ArchiveHook` moves old `ActiveRecord` records out of their table and into a parallel
`_archive` table, following a dependency tree so related child records are archived (or
restored) together. It's designed for pruning large, fast-growing tables (reservations,
payments, logs, etc.) without losing the data — everything just moves to `<table>_archive`.

Archiving is done with raw `INSERT INTO ... SELECT` + `DELETE`/`delete_all` SQL run inside a
transaction, in batches, so it stays reasonably efficient on large tables.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'archive_hook'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install archive_hook

## Setup

For every model you want to archive, create a sibling `<table_name>_archive` table with the
same columns. A Rails generator is included to scaffold the migration for you:

    $ rails generate archive_hook Board

which creates `db/migrate/..._create_boards_archive.rb`:

```ruby
class CreateBoardsArchive < ActiveRecord::Migration[7.0]
  def up
    execute("CREATE TABLE boards_archive (LIKE boards)")
  end

  def down
    drop_table :boards_archive
  end
end
```

Run the generator for the root model and for every model listed under a `children:` entry in
your dependency mapping (see below) — each one needs its own `_archive` table.

> **Postgres only (for now):** the generator's `CREATE TABLE ... (LIKE ...)` is Postgres syntax.
> On other databases, write the `_archive` table migration by hand instead — the archiving and
> restoring API itself (`.archive`, `.archive_scope`, `.restore_scope`) is plain SQL
> (`INSERT INTO ... SELECT`, `DELETE ... WHERE id IN (...)`) run through the ActiveRecord
> connection, so it isn't tied to any particular adapter.

`ArchiveHook` reads the columns off the model at call time, so the archive table just needs to
have matching column names — it doesn't need matching constraints, indexes, or an FK to the
original table.

## Usage

### Archiving everything older than a date (`.archive`)

`ArchiveHook.archive(model, date, dependencies)` finds root records older than `date` (by
`created_at`, or a custom column — see below) and archives them together with their declared
children:

```ruby
ArchiveHook.archive(Board, 1.year.ago, Board => { children: [Card] }, Card => { children: [Tag] })
```

Typically run from a scheduled job:

```ruby
class ArchiveOldBoardsJob
  MAPPING = {
    Board => { children: [Card] },
    Card => { children: [Tag] }
  }

  def self.perform
    ArchiveHook.archive(Board, 1.year.ago, MAPPING)
  end
end
```

To archive by a column other than `created_at`, set `column:` on the root model's entry:

```ruby
ArchiveHook.archive(Board, 1.year.ago, Board => { children: [Card], column: :published_at })
```

Only root records matching the date filter are selected — children are archived because they
belong to an archived root, not because they're independently outdated.

### Archiving an arbitrary scope (`.archive_scope`)

`ArchiveHook.archive_scope(scope, dependencies = {})` archives whatever `ActiveRecord::Relation`
you pass in, applying the same dependency tree to its children. This is handy when the set of
records to archive isn't simply "older than X":

```ruby
ArchiveHook.archive_scope(Board.where(id: stale_ids), Board => { children: [Card] })
```

`dependencies` can be omitted (or `nil`) when the scope has no children to cascade to:

```ruby
ArchiveHook.archive_scope(Tag.where(id: stale_tag_ids), nil)
```

### Restoring archived records (`.restore_scope`)

`ArchiveHook.restore_scope(scope, dependencies = {})` does the reverse: it reads from
`<table>_archive` (aliased to the original table name, so you can scope/query it normally),
re-inserts into the original table, and deletes the archived rows — again cascading through
`dependencies`:

```ruby
ArchiveHook.restore_scope(Board.where(id: board_ids), Board => { children: [Card] })
```

### Dependency mapping

`dependencies` is a `{ model => { children: [...], column: :... } }` hash:

- `children` — models that belong to this one (matched by the inferred foreign key, e.g.
  `Card` is expected to have a `board_id` column when nested under `Board`) and that should be
  archived/restored along with it.
- `column` — the timestamp column used by `.archive` to decide what's "old"; defaults to
  `:created_at`. Only relevant for the root model passed to `.archive`.

Every level of the tree that has further descendants must have its own `children` entry — a
model that's missing from `dependencies` is treated as a leaf. If it's actually a leaf that's
fine, but if it has its own children that aren't declared, deleting it will violate the foreign
key from its undeclared children and raise an `ActiveRecordError`.

## Notes / gotchas

- All archiving/restoring runs in batches (`in_batches`), each batch wrapped in its own
  transaction — a failure partway through can leave earlier batches archived.
- `default_scope` on a model doesn't hide it from `ArchiveHook.archive` — it operates on
  `unscoped` relations internally.
- Because `.archive` only filters the root by date, make sure children are only ever reachable
  through an archived root (or archive/restore them explicitly via `.archive_scope`).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to
run the tests (they need a local Postgres instance; the suite creates and drops an
`archive_hook_test` database automatically). You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new
version, update the version number in `version.rb`, and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and tags, and push the `.gem`
file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ArchiveHook project's codebases, issue trackers, chat rooms and
mailing lists is expected to follow the
[code of conduct](https://github.com/alvir/archive_hook/blob/main/CODE_OF_CONDUCT.md).
