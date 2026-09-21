# frozen_string_literal: true

require "rails/engine"

module HybridSearch
  # Wires HybridSearch::Model into ActiveRecord::Base once Active Record has
  # loaded, and exposes the hybrid_search:* rake tasks to the host app.
  class Engine < ::Rails::Engine
    engine_name "hybrid_search"

    initializer "hybrid_search.active_record" do
      ActiveSupport.on_load(:active_record) do
        include HybridSearch::Model
      end
    end

    rake_tasks do
      path = File.expand_path("tasks/hybrid_search.rake", __dir__)
      load path
    end
  end
end
