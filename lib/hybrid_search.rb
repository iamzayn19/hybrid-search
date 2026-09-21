# frozen_string_literal: true

require "active_support"
require "active_record"

require_relative "hybrid_search/version"
require_relative "hybrid_search/errors"
require_relative "hybrid_search/configuration"
require_relative "hybrid_search/instrumentation"
require_relative "hybrid_search/embeddings"
require_relative "hybrid_search/embeddings/provider"
require_relative "hybrid_search/embeddings/fake"
require_relative "hybrid_search/embeddings/callable"
require_relative "hybrid_search/embeddings/ruby_llm"
require_relative "hybrid_search/definition"
require_relative "hybrid_search/ranking/rrf"
require_relative "hybrid_search/ranking/recency"
require_relative "hybrid_search/keyword/postgres"
require_relative "hybrid_search/semantic/neighbor"
require_relative "hybrid_search/result"
require_relative "hybrid_search/result_set"
require_relative "hybrid_search/search"
require_relative "hybrid_search/global_search"
require_relative "hybrid_search/task_support"
require_relative "hybrid_search/backfill"
require_relative "hybrid_search/doctor"
require_relative "hybrid_search/jobs/embed_record_job"
require_relative "hybrid_search/model"

require_relative "hybrid_search/engine" if defined?(Rails::Engine)

# HybridSearch gives Rails applications hybrid keyword + semantic search using
# the PostgreSQL database they already run. See README.md for the full guide.
module HybridSearch
  class << self
    # Multi-model / global search across several fusion_search-configured
    # models, with a second rank-fusion layer combining each model's
    # independent hybrid ranking.
    #
    #   HybridSearch.search("AI events in London", models: [Event, Article], limit: 20)
    def search(query, models:, **)
      GlobalSearch.new(query, models: models, **).call
    end
  end
end
