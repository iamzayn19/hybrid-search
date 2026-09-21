# frozen_string_literal: true

module RailsFusion
  module Ranking
    # Bounded exponential-decay recency boost. The maximum possible
    # contribution is capped to roughly one RRF rank-1 contribution so
    # recency cannot swamp lexical/semantic relevance by default.
    #
    # Deterministic given an injected clock; nil timestamps receive no boost.
    module Recency
      module_function

      def contribution(timestamp, half_life:, rrf_k:, clock: Time.now)
        return 0.0 if timestamp.nil?

        half_life_seconds = half_life.to_f
        return 0.0 unless half_life_seconds.positive?

        age_seconds = [clock.to_f - timestamp.to_time.to_f, 0.0].max
        decay = 0.5**(age_seconds / half_life_seconds)
        decay * (1.0 / rrf_k)
      end
    end
  end
end
