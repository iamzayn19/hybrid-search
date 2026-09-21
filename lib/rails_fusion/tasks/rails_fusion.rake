# frozen_string_literal: true

namespace :rails_fusion do
  desc "Check RailsFusion configuration and database health (MODEL=Product optional)"
  task doctor: :environment do
    model = RailsFusion::TaskSupport.resolve_model(ENV.fetch("MODEL", nil))
    checks = RailsFusion::Doctor.new(model).call

    checks.each do |check|
      icon = { ok: "OK ", warning: "WARN", error: "FAIL" }.fetch(check.status)
      puts "[#{icon}] #{check.name}: #{check.message}"
    end

    exit(1) unless RailsFusion::Doctor.new(model).ok?(checks)
  end

  desc "Show embedding status for a model (MODEL=Product)"
  task status: :environment do
    model = RailsFusion::TaskSupport.require_model!(ENV.fetch("MODEL", nil))
    definition = model.rails_fusion_definition
    cfg = definition.embedding_config

    total = model.count
    puts "Model:            #{model.name}"
    puts "Records:          #{total}"
    puts "Keyword fields:   #{definition.text_fields.map(&:name).join(", ")}"
    puts "Filters:          #{definition.filters.join(", ")}"

    if cfg
      missing = model.where(cfg.column => nil).count
      puts "Embedding column: #{cfg.column} (#{cfg.dimensions} dims, #{cfg.distance})"
      puts "Provider:         #{cfg.provider.inspect} / #{cfg.model.inspect}"
      puts "Embedded:         #{total - missing}"
      puts "Missing:          #{missing}"
    else
      puts "Embedding:        not configured (keyword-only)"
    end
  end

  desc "Backfill embeddings for a model (MODEL=Product BATCH_SIZE=500 FORCE=true ASYNC=true)"
  task backfill: :environment do
    model = RailsFusion::TaskSupport.require_model!(ENV.fetch("MODEL", nil))
    batch_size = (ENV["BATCH_SIZE"] || 500).to_i
    mode = ActiveModel::Type::Boolean.new.cast(ENV.fetch("ASYNC", nil)) ? :async : :sync
    force = ActiveModel::Type::Boolean.new.cast(ENV.fetch("FORCE", nil))
    fail_fast = ActiveModel::Type::Boolean.new.cast(ENV.fetch("FAIL_FAST", nil))

    summary = RailsFusion::Backfill.new(
      model, batch_size: batch_size, mode: mode, force: force, fail_fast: fail_fast,
             progress: lambda { |s|
               print "\rProcessed #{s.processed} (embedded #{s.embedded}, skipped #{s.skipped}, failed #{s.failed})"
             }
    ).call

    puts
    puts "Done. processed=#{summary.processed} embedded=#{summary.embedded} " \
         "skipped=#{summary.skipped} failed=#{summary.failed}"
    summary.errors.first(20).each { |e| puts "  #{e}" }
    exit(1) if fail_fast && summary.failed.positive?
  end
end
