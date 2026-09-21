# frozen_string_literal: true

require "rails/generators"

module HybridSearch
  module Generators
    # bin/rails generate hybrid_search:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Creates a HybridSearch initializer with commented safe defaults."

      def create_initializer
        template "initializer.rb", "config/initializers/hybrid_search.rb"
      end
    end
  end
end
