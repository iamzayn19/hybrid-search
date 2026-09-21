# frozen_string_literal: true

module RailsFusion
  # Safely resolves a MODEL= environment variable to an ActiveRecord class
  # that is actually configured with `fusion_search`. Never blindly
  # `constantize`s arbitrary input.
  module TaskSupport
    module_function

    def resolve_model(name)
      return nil if name.nil? || name.strip.empty?

      klass = name.to_s.safe_constantize
      unless klass.is_a?(Class) && klass < ActiveRecord::Base
        raise ConfigurationError, "MODEL=#{name} is not a known ActiveRecord model."
      end
      unless klass.respond_to?(:fusion_searchable?) && klass.fusion_searchable?
        raise ConfigurationError, "#{klass} has no `fusion_search do ... end` block configured."
      end

      klass
    end

    def require_model!(name)
      resolve_model(name) || raise(ConfigurationError, "Set MODEL=YourModel for this task.")
    end
  end
end
