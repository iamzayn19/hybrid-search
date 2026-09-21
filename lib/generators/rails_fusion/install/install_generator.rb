# frozen_string_literal: true

require "rails/generators"

module RailsFusion
  module Generators
    # bin/rails generate rails_fusion:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Creates a RailsFusion initializer with commented safe defaults."

      def create_initializer
        template "initializer.rb", "config/initializers/rails_fusion.rb"
      end
    end
  end
end
