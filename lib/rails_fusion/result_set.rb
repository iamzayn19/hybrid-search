# frozen_string_literal: true

module RailsFusion
  # An ordered, materialized collection of Result objects. Deliberately not
  # an ActiveRecord::Relation: the result set is already fused from multiple
  # candidate lists and further AR chaining would be misleading.
  class ResultSet
    include Enumerable

    attr_reader :results, :fallback

    def initialize(results, fallback: nil)
      @results = results
      @fallback = fallback
    end

    def each(&)
      return enum_for(:each) unless block_given?

      results.each(&)
    end

    def records
      results.map(&:record)
    end

    def first
      results.first
    end

    def empty?
      results.empty?
    end

    def size
      results.size
    end
    alias length size
    alias count size

    def semantic_degraded?
      !fallback.nil?
    end

    def as_json(*)
      results.map(&:as_json)
    end
  end
end
