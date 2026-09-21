# Examples

Documented model/search snippets. All use `RailsFusion::Embeddings::Fake`, a deterministic,
local, no-network provider — no API keys required to try these.

## 1. Products

```ruby
class Product < ApplicationRecord
  fusion_search do
    text :name, weight: :a
    text :description, weight: :b
    embedding :search_embedding, dimensions: 16,
              provider: RailsFusion::Embeddings::Fake.new(dimensions: 16), auto: true
    filter :account_id
    filter :status
  end
end

Product.fusion_search("wireless headphones", where: { account_id: 1, status: "published" })
```

## 2. Knowledge-base articles

```ruby
class Article < ApplicationRecord
  fusion_search do
    text :title, weight: :a
    text :body, weight: :b
    embedding :embedding, dimensions: 16,
              provider: RailsFusion::Embeddings::Fake.new(dimensions: 16), auto: true
    filter :account_id
    recency :published_at, half_life: 30.days
  end
end
```

## 3. Tenant-scoped search

```ruby
Article.fusion_search("refund policy", where: { account_id: current_account.id })
```

`account_id` is a declared filter, applied identically to both the keyword and semantic
candidate queries — a record from another tenant can never leak in as a "close" semantic
match. See `test/security/adversarial_test.rb` for the isolation tests.

## 4. Exact identifier vs. semantic case

```ruby
# Exact lexical match wins:
Product.fusion_search("Error 503 from Stripe")

# Meaning-only match (no shared keywords) can still surface via the semantic channel,
# ranked alongside lexical matches through RRF:
Product.fusion_search("payment gateway is down")
```

## 5. Multi-model global search

```ruby
RailsFusion.search(
  "AI events in London",
  models: [Event, Article],
  where: { Event => { account_id: 1 }, Article => { account_id: 1 } },
  limit: 20
)
```
