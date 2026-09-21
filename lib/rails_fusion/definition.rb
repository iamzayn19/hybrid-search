# frozen_string_literal: true

module RailsFusion
  # Holds the parsed configuration built by a model's `fusion_search do ... end`
  # block. One instance per model class.
  class Definition
    TextField = Struct.new(:name, :weight, keyword_init: true)

    EmbeddingConfig = Struct.new(
      :column, :dimensions, :provider, :model, :distance, :source, :auto, :digest_column,
      keyword_init: true
    )

    RecencyConfig = Struct.new(:column, :half_life, keyword_init: true)

    VALID_WEIGHTS = %i[a b c d].freeze
    VALID_DISTANCES = %i[cosine l2 inner_product].freeze

    attr_reader :model_class, :text_fields, :embedding_config, :filters, :recency_config,
                :text_search_config

    def initialize(model_class)
      @model_class = model_class
      @text_fields = []
      @embedding_config = nil
      @filters = []
      @recency_config = nil
      @text_search_config = "english"
    end

    def text(name, weight: :a)
      name = name.to_sym
      unless VALID_WEIGHTS.include?(weight)
        raise ConfigurationError, "text field `#{name}` weight must be one of #{VALID_WEIGHTS}, got #{weight.inspect}"
      end

      @text_fields << TextField.new(name: name, weight: weight)
    end

    def embedding(column, dimensions:, provider: nil, model: nil, distance: :cosine, source: nil, auto: false)
      column = column.to_sym
      unless dimensions.is_a?(Integer) && dimensions.positive?
        raise ConfigurationError, "embedding `dimensions` must be a positive integer, got #{dimensions.inspect}"
      end
      unless VALID_DISTANCES.include?(distance)
        raise ConfigurationError, "embedding `distance` must be one of #{VALID_DISTANCES}, got #{distance.inspect}"
      end

      source_fields = Array(source || @text_fields.map(&:name)).map(&:to_sym)
      if source_fields.empty?
        raise ConfigurationError, "embedding `source` must include at least one field (declare `text` fields first)"
      end

      @embedding_config = EmbeddingConfig.new(
        column: column,
        dimensions: dimensions,
        provider: provider,
        model: model,
        distance: distance,
        source: source_fields,
        auto: auto,
        digest_column: :"#{column}_digest"
      )
    end

    def filter(name)
      @filters << name.to_sym
    end

    def recency(column, half_life:)
      @recency_config = RecencyConfig.new(column: column.to_sym, half_life: half_life)
    end

    def text_search_config=(value)
      @text_search_config = value.to_s
    end

    def filter?(name)
      @filters.include?(name.to_sym)
    end

    # Validate the definition against the actual model schema. Raises
    # ConfigurationError with an actionable message on any mismatch.
    def validate!
      validate_text_fields!
      validate_embedding!
      validate_filters!
      validate_recency!
      self
    end

    private

    def columns
      @columns ||= model_class.columns_hash.keys.map(&:to_sym)
    end

    def validate_text_fields!
      @text_fields.each do |field|
        next if columns.include?(field.name)

        raise ConfigurationError,
              "#{model_class}: `text :#{field.name}` does not match a column. " \
              "Available columns: #{columns.join(", ")}"
      end
    end

    def validate_embedding!
      return unless embedding_config

      unless columns.include?(embedding_config.column)
        raise ConfigurationError,
              "#{model_class}: embedding column `#{embedding_config.column}` does not exist. " \
              "Add it with the rails_fusion:index generator."
      end

      if embedding_config.auto && !columns.include?(embedding_config.digest_column)
        raise ConfigurationError,
              "#{model_class}: auto embeddings require a `#{embedding_config.digest_column}` " \
              "column. Add it with the rails_fusion:index generator."
      end

      embedding_config.source.each do |field_name|
        next if columns.include?(field_name)

        raise ConfigurationError,
              "#{model_class}: embedding source field `#{field_name}` does not match a column."
      end
    end

    def validate_filters!
      @filters.each do |name|
        next if columns.include?(name)

        raise ConfigurationError,
              "#{model_class}: `filter :#{name}` does not match a column. " \
              "Available columns: #{columns.join(", ")}"
      end
    end

    def validate_recency!
      return unless recency_config

      unless columns.include?(recency_config.column)
        raise ConfigurationError,
              "#{model_class}: `recency :#{recency_config.column}` does not match a column."
      end

      return if recency_config.half_life.respond_to?(:to_f) && recency_config.half_life.to_f.positive?

      raise ConfigurationError, "#{model_class}: recency half_life must be a positive duration."
    end
  end
end
