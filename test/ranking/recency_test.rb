# frozen_string_literal: true

require "test_helper"

class RecencyTest < Minitest::Test
  def test_nil_timestamp_gets_no_boost
    assert_equal 0.0, RailsFusion::Ranking::Recency.contribution(nil, half_life: 86_400, rrf_k: 60)
  end

  def test_newer_result_gets_larger_bounded_boost
    clock = Time.at(1_000_000)
    newer = clock - 60
    older = clock - (10 * 86_400)

    newer_score = RailsFusion::Ranking::Recency.contribution(newer, half_life: 86_400, rrf_k: 60, clock: clock)
    older_score = RailsFusion::Ranking::Recency.contribution(older, half_life: 86_400, rrf_k: 60, clock: clock)

    assert_operator newer_score, :>, older_score
    assert_operator newer_score, :<=, 1.0 / 60
  end

  def test_deterministic_with_frozen_clock
    clock = Time.at(2_000_000)
    ts = clock - 3600
    a = RailsFusion::Ranking::Recency.contribution(ts, half_life: 86_400, rrf_k: 60, clock: clock)
    b = RailsFusion::Ranking::Recency.contribution(ts, half_life: 86_400, rrf_k: 60, clock: clock)
    assert_equal a, b
  end
end
