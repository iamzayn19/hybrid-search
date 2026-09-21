# frozen_string_literal: true

require "active_support"
require "active_record"

require_relative "rails_fusion/version"
require_relative "rails_fusion/errors"
require_relative "rails_fusion/configuration"
require_relative "rails_fusion/instrumentation"
require_relative "rails_fusion/embeddings"
require_relative "rails_fusion/embeddings/provider"
require_relative "rails_fusion/embeddings/fake"
require_relative "rails_fusion/embeddings/callable"
require_relative "rails_fusion/embeddings/ruby_llm"
require_relative "rails_fusion/definition"
require_relative "rails_fusion/ranking/rrf"
require_relative "rails_fusion/ranking/recency"
require_relative "rails_fusion/keyword/postgres"
require_relative "rails_fusion/semantic/neighbor"
require_relative "rails_fusion/result"
require_relative "rails_fusion/result_set"
require_relative "rails_fusion/search"
require_relative "rails_fusion/global_search"
require_relative "rails_fusion/task_support"
require_relative "rails_fusion/backfill"
require_relative "rails_fusion/doctor"
require_relative "rails_fusion/jobs/embed_record_job"
require_relative "rails_fusion/model"

require_relative "rails_fusion/engine" if defined?(Rails::Engine)

# RailsFusion gives Rails applications hybrid keyword + semantic search using
# the PostgreSQL database they already run. See README.md for the full guide.
module RailsFusion
  class << self
    # Multi-model / global search across several fusion_search-configured
    # models, with a second rank-fusion layer combining each model's
    # independent hybrid ranking.
    #
    #   RailsFusion.search("AI events in London", models: [Event, Article], limit: 20)
    def search(query, models:, **)
      GlobalSearch.new(query, models: models, **).call
    end
  end
end
