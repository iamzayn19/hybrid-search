# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"
require "digest"

module HybridSearch
  module Generators
    # bin/rails generate hybrid_search:index Product name description \
    #   --embedding-column=search_embedding --dimensions=1536 --distance=cosine
    class IndexGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Generates a migration adding pgvector + full-text search columns/indexes for a model."

      argument :model_name, type: :string, banner: "ModelName"
      argument :text_fields, type: :array, default: [], banner: "field field"

      class_option :embedding_column, type: :string, default: "search_embedding"
      class_option :dimensions, type: :numeric, default: 1536
      class_option :distance, type: :string, default: "cosine"

      def self.next_migration_number(dirname)
        next_number = current_migration_number(dirname) + 1
        if ActiveRecord::Base.respond_to?(:timestamped_migrations) && !ActiveRecord::Base.timestamped_migrations
          format("%.3d", next_number)
        else
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        end
      end

      def create_migration_file
        migration_template "migration.rb.erb", "db/migrate/add_hybrid_search_to_#{table_name}.rb"
      end

      private

      def table_name
        @table_name ||= model_name.underscore.pluralize
      end

      def migration_class_name
        "AddHybridSearchTo#{model_name.camelize.pluralize}"
      end

      def embedding_column
        options["embedding_column"]
      end

      def digest_column
        "#{embedding_column}_digest"
      end

      def dimensions
        options["dimensions"].to_i
      end

      def distance_option
        options["distance"]
      end

      def distance_ops
        {
          "cosine" => "vector_cosine_ops",
          "l2" => "vector_l2_ops",
          "inner_product" => "vector_ip_ops"
        }.fetch(distance_option, "vector_cosine_ops")
      end

      # PostgreSQL identifiers are limited to 63 bytes. Keep generated index
      # names short, stable, and collision-resistant.
      def index_name(suffix)
        base = "idx_rf_#{table_name}_#{suffix}"
        return base if base.bytesize <= 63

        digest = Digest::MD5.hexdigest(base)[0, 8]
        "idx_rf_#{digest}_#{suffix}"[0, 63]
      end

      def tsvector_expression
        columns = text_fields.map { |f| "coalesce(#{f}, '')" }
        "to_tsvector('english', #{columns.join(" || ' ' || ")})"
      end
    end
  end
end
