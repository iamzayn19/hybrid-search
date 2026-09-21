# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in rails_fusion.gemspec
gemspec

rails_version = ENV.fetch("RAILS_VERSION", nil)
if rails_version && !rails_version.empty?
  gem "activejob", rails_version
  gem "activerecord", rails_version
  gem "activesupport", rails_version
  gem "railties", rails_version
end

gem "irb"
gem "rake", "~> 13.0"

gem "minitest", "~> 5.16"

gem "rubocop", "~> 1.21"
