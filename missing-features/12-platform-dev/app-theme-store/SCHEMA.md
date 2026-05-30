# SCHEMA: App & Theme Store

Migration: `241_store.sql`.

## store_listings
```sql
CREATE TABLE store_listings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            text NOT NULL UNIQUE,
  publisher_id    uuid NOT NULL REFERENCES users(id),
  type            text NOT NULL CHECK (type IN ('plugin','theme','stickers','sounds')),
  display_name    text NOT NULL,
  summary         text NOT NULL CHECK (length(summary) <= 140),
  description_md  text NOT NULL,
  hero_url        text,
  gallery_urls    text[] NOT NULL DEFAULT '{}',
  category        text NOT NULL,
  tags            text[] NOT NULL DEFAULT '{}',
  price_cents     integer NOT NULL DEFAULT 0,
  price_currency  text NOT NULL DEFAULT 'USD',
  billing         text NOT NULL DEFAULT 'free'
                    CHECK (billing IN ('free','one_time','sub_month','sub_year')),
  status          text NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','submitted','in_review','changes_requested','rejected','approved','published','taken_down','deprecated')),
  ref_id          text,                                -- plugin id, theme id, etc.
  install_count   integer NOT NULL DEFAULT 0,
  rating_avg      numeric(3,2),
  rating_count    integer NOT NULL DEFAULT 0,
  search_vec      tsvector
                    GENERATED ALWAYS AS (
                      to_tsvector('english',
                        coalesce(display_name,'') || ' ' ||
                        coalesce(summary,'') || ' ' ||
                        array_to_string(tags,' '))
                    ) STORED,
  created_at      timestamptz NOT NULL DEFAULT now(),
  published_at    timestamptz
);
CREATE INDEX listings_status_idx ON store_listings(status) WHERE status='published';
CREATE INDEX listings_search_idx ON store_listings USING gin(search_vec);
CREATE INDEX listings_trgm_idx ON store_listings USING gin(display_name gin_trgm_ops);
CREATE INDEX listings_publisher_idx ON store_listings(publisher_id);

ALTER TABLE store_listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY listings_public_read ON store_listings FOR SELECT
  USING (status='published' OR publisher_id = auth.uid()
         OR auth.jwt() ->> 'role' = 'reviewer');
CREATE POLICY listings_owner_write ON store_listings FOR ALL
  USING (publisher_id = auth.uid());
```

## store_purchases
```sql
CREATE TABLE store_purchases (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      uuid NOT NULL REFERENCES store_listings(id),
  buyer_id        uuid NOT NULL REFERENCES users(id),
  server_id       uuid REFERENCES servers(id),
  amount_cents    integer NOT NULL,
  currency        text NOT NULL,
  state           text NOT NULL DEFAULT 'pending'
                    CHECK (state IN ('pending','paid','failed','refunded','installed','uninstalled')),
  pay_session_id  text,
  pay_charge_id   text,
  refunded_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  installed_at    timestamptz,
  idem_key        text NOT NULL,
  UNIQUE (idem_key)
);
CREATE INDEX purchases_buyer_idx ON store_purchases(buyer_id, created_at DESC);
CREATE INDEX purchases_listing_idx ON store_purchases(listing_id);
CREATE INDEX purchases_state_idx ON store_purchases(state) WHERE state IN ('pending','failed');
ALTER TABLE store_purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY purchases_self ON store_purchases FOR SELECT
  USING (buyer_id = auth.uid() OR auth.jwt() ->> 'role' IN ('reviewer','admin'));
```

## store_reviews
```sql
CREATE TABLE store_reviews (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id      uuid NOT NULL REFERENCES store_listings(id) ON DELETE CASCADE,
  author_id       uuid NOT NULL REFERENCES users(id),
  server_id       uuid NOT NULL REFERENCES servers(id),
  rating          smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body            text CHECK (length(body) <= 1000),
  helpful_count   integer NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  hidden          boolean NOT NULL DEFAULT false,
  hidden_reason   text,
  UNIQUE (listing_id, server_id)
);
CREATE INDEX reviews_listing_idx ON store_reviews(listing_id, hidden, created_at DESC);

ALTER TABLE store_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY reviews_read ON store_reviews FOR SELECT USING (NOT hidden);
CREATE POLICY reviews_write ON store_reviews FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM plugin_installs pi
       WHERE pi.server_id = store_reviews.server_id
         AND pi.installed_at < now() - interval '24 hours'
    )
  );
```

## store_review_queue (view)
```sql
CREATE VIEW store_review_queue AS
  SELECT l.id, l.display_name, l.type, l.status, l.published_at,
         (l.created_at) AS submitted_at,
         CASE WHEN type='plugin' AND
                (SELECT scopes FROM plugin_versions WHERE plugin_id = l.ref_id ORDER BY uploaded_at DESC LIMIT 1)
                <> coalesce(l.tags, '{}') THEN 'cap_change' ELSE 'normal' END AS priority
    FROM store_listings l
   WHERE l.status IN ('submitted','in_review');
```

## Triggers
- `listings_review_aggregate`: recomputes `rating_avg`, `rating_count` on review insert/update.
- `purchases_idem_guard`: rejects duplicate `idem_key`.
- `audit_listing_status`: writes audit row on status change with old/new status and actor.
