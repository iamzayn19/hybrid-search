# frozen_string_literal: true

require "rails/engine"

module RailsFusion
  # Wires RailsFusion::Model into ActiveRecord::Base once Active Record has
  # loaded, and exposes the rails_fusion:* rake tasks to the host app.
  class Engine < ::Rails::Engine
    engine_name "rails_fusion"

    initializer "rails_fusion.active_record" do
      ActiveSupport.on_load(:active_record) do
        include RailsFusion::Model
      end
    end

    rake_tasks do
      path = File.expand_path("tasks/rails_fusion.rake", __dir__)
      load path
    end
  end
end
