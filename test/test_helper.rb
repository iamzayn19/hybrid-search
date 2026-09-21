# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_record"
require "active_job"
require "hybrid_search"
require "minitest/autorun"

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = nil

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  host: ENV.fetch("PGHOST", "localhost"),
  port: ENV.fetch("PGPORT", "5433").to_i,
  username: ENV.fetch("PGUSER", ENV.fetch("USER", nil)),
  database: ENV.fetch("PGDATABASE", "hybrid_search_test")
)
ActiveRecord::Base.logger = nil
ActiveRecord::Base.include(HybridSearch::Model) unless ActiveRecord::Base < HybridSearch::Model

require_relative "support/schema"
require_relative "support/models"

module HybridSearch
  class TestCase < Minitest::Test
    TABLES = %w[fusion_products fusion_articles fusion_docs].freeze

    def setup
      HybridSearch.reset_configuration!
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      ActiveJob::Base.queue_adapter.performed_jobs.clear
    end

    def teardown
      TABLES.each { |t| ActiveRecord::Base.connection.execute(%(TRUNCATE TABLE "#{t}" RESTART IDENTITY CASCADE)) }
    end

    def freeze_time(at)
      at
    end
  end
end
