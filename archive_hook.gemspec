
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "archive_hook/version"

Gem::Specification.new do |spec|
  spec.name          = "archive_hook"
  spec.version       = ArchiveHook::VERSION
  spec.authors       = ["alvir"]
  spec.email         = ["shurik.v.r@gmail.com"]

  spec.summary       = %q{Archive ActiveRecord models (and their dependents) to parallel _archive tables}
  spec.description   = %q{Moves old ActiveRecord records into sibling <table>_archive tables, cascading through a declared parent/child dependency tree, with support for restoring them back.}
  spec.homepage      = "https://github.com/alvir/archive_hook"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = spec.homepage
    # spec.metadata["changelog_uri"] = ""
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Only ActiveRecord (+ Arel, bundled with it) is used at runtime; no need for full Rails.
  spec.add_dependency "activerecord", ">= 5.2", "< 9"

  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
