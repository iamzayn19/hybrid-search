# frozen_string_literal: true

require "test_helper"

class UuidPrimaryKeyTest < RailsFusion::TestCase
  def test_search_works_with_uuid_primary_key
    doc = FusionDoc.create!(name: "UUID doc", description: "identifies by uuid")
    provider = FusionDoc.rails_fusion_definition.embedding_config.provider
    doc.update_columns(search_embedding: provider.embed(["UUID doc identifies by uuid"]).first)

    results = FusionDoc.fusion_search("UUID doc")

    assert_kind_of String, doc.id
    assert_includes results.records.map(&:id), doc.id
  end
end
