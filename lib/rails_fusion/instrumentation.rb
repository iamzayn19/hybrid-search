# frozen_string_literal: true

require "active_support/notifications"

module RailsFusion
  # Thin wrapper around ActiveSupport::Notifications. Payloads never include
  # secrets, full embedding vectors, or raw search query text by default.
  module Instrumentation
    module_function

    def instrument(event, payload = {}, &)
      ActiveSupport::Notifications.instrument("#{event}.rails_fusion", payload, &)
    end
  end
end
