# frozen_string_literal: true

require_relative "lib/rails_fusion/version"

Gem::Specification.new do |spec|
  spec.name = "rails_fusion"
  spec.version = RailsFusion::VERSION
  spec.authors = ["iamzayn19"]
  spec.email = ["iamzayn19@gmail.com"]

  spec.summary = "Hybrid keyword + semantic search for Rails, powered by Postgres."
  spec.description = "RailsFusion gives Rails applications hybrid keyword and semantic search " \
                     "using the PostgreSQL database they already run: full-text search, " \
                     "pgvector semantic similarity, reciprocal rank fusion, an automatic " \
                     "embedding lifecycle, safe multi-tenant filters, explainable ranking, " \
                     "and operational tooling. No Elasticsearch, no separate vector database."
  spec.homepage = "https://github.com/iamzayn19/rails-fusion"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["changelog_uri"] = "https://github.com/iamzayn19/rails-fusion/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/iamzayn19/rails-fusion/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ .github/ .rubocop.yml .ruby-version spec/ examples/ benchmark/]) ||
        %w[Gemfile.lock].include?(f)
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activejob", ">= 7.2", "< 9"
  spec.add_dependency "activerecord", ">= 7.2", "< 9"
  spec.add_dependency "activesupport", ">= 7.2", "< 9"
  spec.add_dependency "neighbor", ">= 0.5", "< 2.0"
  spec.add_dependency "railties", ">= 7.2", "< 9"

  spec.add_development_dependency "pg", "~> 1.5"
end
