# frozen_string_literal: true

require "test_helper"

class RRFTest < Minitest::Test
  def test_combines_contributions_from_both_channels
    fused = HybridSearch::Ranking::RRF.fuse(
      keyword_ranks: { "1" => 1, "2" => 2 },
      semantic_ranks: { "1" => 3 },
      keyword_weight: 1.0, semantic_weight: 1.0, rrf_k: 60
    )

    expected = (1.0 / 61) + (1.0 / 63)
    assert_in_delta expected, fused["1"].score, 1e-9
    assert_equal 1, fused["1"].keyword_rank
    assert_equal 3, fused["1"].semantic_rank
  end

  def test_missing_channel_contributes_zero_but_stays_eligible
    fused = HybridSearch::Ranking::RRF.fuse(
      keyword_ranks: {}, semantic_ranks: { "5" => 1 },
      keyword_weight: 1.0, semantic_weight: 1.0, rrf_k: 60
    )

    assert_equal 1.0 / 61, fused["5"].score
    assert_nil fused["5"].keyword_rank
  end

  def test_weight_overrides_change_score
    fused = HybridSearch::Ranking::RRF.fuse(
      keyword_ranks: { "1" => 1 }, semantic_ranks: {},
      keyword_weight: 2.0, semantic_weight: 1.0, rrf_k: 60
    )

    assert_in_delta 2.0 / 61, fused["1"].score, 1e-9
  end
end
