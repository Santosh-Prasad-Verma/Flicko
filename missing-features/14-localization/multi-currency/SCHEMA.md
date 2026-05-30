# Multi-Currency — Backend Schema

## 1. Tables

### `currencies`

Catalog of supported display currencies.

```sql
CREATE TABLE currencies (
  code         TEXT PRIMARY KEY,                 -- ISO 4217: 'USD', 'INR', 'JPY'
  english_name TEXT NOT NULL,                    -- 'Indian Rupee'
  native_name  TEXT NOT NULL,                    -- 'भारतीय रुपया'
  symbol       TEXT NOT NULL,                    -- '₹'
  decimals     SMALLINT NOT NULL DEFAULT 2,      -- 0 (JPY), 2 (USD), 3 (KWD)
  enabled      BOOLEAN NOT NULL DEFAULT true,
  format_pattern TEXT,                            -- e.g. '{symbol}{amount}' or '{amount} {symbol}'
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `currency_rates`

One row per (currency × day). USD is base (rate=1, never written but expected by callers).

```sql
CREATE TABLE currency_rates (
  ccy        TEXT NOT NULL REFERENCES currencies(code),
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  rate       NUMERIC(20,8) NOT NULL CHECK (rate > 0 AND rate < 1e6),
  source     TEXT NOT NULL DEFAULT 'oxr',        -- 'oxr' | 'frankfurter' | 'manual'
  PRIMARY KEY (ccy, fetched_at)
);

CREATE INDEX idx_currency_rates_latest ON currency_rates(ccy, fetched_at DESC);
```

To answer "current rate for INR" we always run:
```sql
SELECT rate FROM currency_rates WHERE ccy = $1 ORDER BY fetched_at DESC LIMIT 1;
```

### `region_currency_defaults`

Maps ISO-3166 alpha-2 region codes to default display currency.

```sql
CREATE TABLE region_currency_defaults (
  region_code TEXT PRIMARY KEY,        -- 'IN', 'BR', 'JP'
  ccy         TEXT NOT NULL REFERENCES currencies(code),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `profiles` (column add)

```sql
ALTER TABLE profiles
  ADD COLUMN preferred_currency TEXT REFERENCES currencies(code),
  ADD COLUMN region_code        TEXT;             -- for default ccy + content filters

CREATE INDEX idx_profiles_preferred_currency ON profiles(preferred_currency);
CREATE INDEX idx_profiles_region_code        ON profiles(region_code);
```

### `transactions` (column adds)

We record what the user *saw* for compliance/forensics.

```sql
ALTER TABLE transactions
  ADD COLUMN displayed_currency  TEXT REFERENCES currencies(code),
  ADD COLUMN displayed_amount    BIGINT,           -- smallest unit
  ADD COLUMN fx_rate_used        NUMERIC(20,8);
```

## 2. RLS Policies

```sql
ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE currency_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE region_currency_defaults ENABLE ROW LEVEL SECURITY;

-- Public read for catalog tables
CREATE POLICY "Public reads currencies" ON currencies FOR SELECT USING (true);
CREATE POLICY "Public reads rates"      ON currency_rates FOR SELECT USING (true);
CREATE POLICY "Public reads region defaults" ON region_currency_defaults FOR SELECT USING (true);

-- Admin / service-role writes
CREATE POLICY "Admin writes currencies" ON currencies FOR ALL
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Service role writes rates" ON currency_rates FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Admin writes region defaults" ON region_currency_defaults FOR ALL
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));
```

## 3. Triggers

```sql
CREATE TRIGGER currencies_set_updated_at
  BEFORE UPDATE ON currencies
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Cache bust: when a fresh rate lands, NOTIFY backend LRU
CREATE OR REPLACE FUNCTION fx_notify_rate_update() RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('fx_rates_updated', NEW.ccy);
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER currency_rates_notify
  AFTER INSERT ON currency_rates
  FOR EACH ROW EXECUTE FUNCTION fx_notify_rate_update();
```

## 4. Migration File

Path: `supabase/migrations/260_multi_currency.up.sql`
Down: `supabase/migrations/260_multi_currency.down.sql`

```sql
-- up
BEGIN;

CREATE TABLE currencies (...);
CREATE TABLE currency_rates (...);
CREATE TABLE region_currency_defaults (...);

ALTER TABLE profiles
  ADD COLUMN preferred_currency TEXT REFERENCES currencies(code),
  ADD COLUMN region_code TEXT;

ALTER TABLE transactions
  ADD COLUMN displayed_currency TEXT REFERENCES currencies(code),
  ADD COLUMN displayed_amount BIGINT,
  ADD COLUMN fx_rate_used NUMERIC(20,8);

-- seed top 50 currencies
INSERT INTO currencies(code, english_name, native_name, symbol, decimals) VALUES
  ('USD', 'US Dollar',           'US Dollar',           '$',   2),
  ('EUR', 'Euro',                'Euro',                '€',   2),
  ('GBP', 'British Pound',       'British Pound',       '£',   2),
  ('JPY', 'Japanese Yen',        '円',                  '¥',   0),
  ('INR', 'Indian Rupee',        'भारतीय रुपया',         '₹',   2),
  ('BRL', 'Brazilian Real',      'Real Brasileiro',     'R$',  2),
  ('CNY', 'Chinese Yuan',        '人民币',              '¥',   2),
  ('KRW', 'South Korean Won',    '대한민국 원',         '₩',   0),
  ('MXN', 'Mexican Peso',        'Peso Mexicano',       'M$',  2),
  ('CAD', 'Canadian Dollar',     'Canadian Dollar',     'CA$', 2),
  ('AUD', 'Australian Dollar',   'Australian Dollar',   'A$',  2),
  ('CHF', 'Swiss Franc',         'Schweizer Franken',   'CHF', 2),
  ('SEK', 'Swedish Krona',       'Svenska kronor',      'kr',  2),
  ('NOK', 'Norwegian Krone',     'Norske kroner',       'kr',  2),
  ('DKK', 'Danish Krone',        'Danske kroner',       'kr',  2),
  ('PLN', 'Polish Złoty',        'Polski złoty',        'zł',  2),
  ('TRY', 'Turkish Lira',        'Türk lirası',         '₺',   2),
  ('RUB', 'Russian Ruble',       'Российский рубль',    '₽',   2),
  ('UAH', 'Ukrainian Hryvnia',   'Українська гривня',   '₴',   2),
  ('AED', 'UAE Dirham',          'درهم إماراتي',        'د.إ', 2),
  ('SAR', 'Saudi Riyal',         'ريال سعودي',          'ر.س', 2),
  ('ILS', 'Israeli Shekel',      'שקל ישראלי',          '₪',   2),
  ('EGP', 'Egyptian Pound',      'جنيه مصري',           'E£',  2),
  ('ZAR', 'South African Rand',  'Suid-Afrikaanse rand','R',   2),
  ('NGN', 'Nigerian Naira',      'Naira',               '₦',   2),
  ('THB', 'Thai Baht',           'บาท',                 '฿',   2),
  ('VND', 'Vietnamese Dong',     'Đồng Việt Nam',       '₫',   0),
  ('IDR', 'Indonesian Rupiah',   'Rupiah Indonesia',    'Rp',  2),
  ('MYR', 'Malaysian Ringgit',   'Ringgit Malaysia',    'RM',  2),
  ('PHP', 'Philippine Peso',     'Piso ng Pilipinas',   '₱',   2),
  ('SGD', 'Singapore Dollar',    'Singapore Dollar',    'S$',  2),
  ('HKD', 'Hong Kong Dollar',    'Hong Kong Dollar',    'HK$', 2),
  ('TWD', 'New Taiwan Dollar',   '新台幣',              'NT$', 0),
  ('NZD', 'NZ Dollar',           'NZ Dollar',           'NZ$', 2),
  ('ARS', 'Argentine Peso',      'Peso argentino',      'AR$', 2),
  ('CLP', 'Chilean Peso',        'Peso chileno',        'CL$', 0),
  ('COP', 'Colombian Peso',      'Peso colombiano',     'CO$', 0),
  ('PEN', 'Peruvian Sol',        'Sol peruano',         'S/',  2),
  ('PKR', 'Pakistani Rupee',     'پاکستانی روپیہ',      '₨',   2),
  ('BDT', 'Bangladeshi Taka',    'বাংলাদেশী টাকা',       '৳',   2),
  ('LKR', 'Sri Lankan Rupee',    'ශ්‍රී ලංකා රුපියල',     'Rs',  2),
  ('KES', 'Kenyan Shilling',     'Shilingi',            'KSh', 2),
  ('GHS', 'Ghanaian Cedi',       'Cedi',                'GH₵', 2),
  ('MAD', 'Moroccan Dirham',     'درهم مغربي',          'DH',  2),
  ('CZK', 'Czech Koruna',        'Česká koruna',        'Kč',  2),
  ('HUF', 'Hungarian Forint',    'Magyar forint',       'Ft',  2),
  ('RON', 'Romanian Leu',        'Leu românesc',        'lei', 2),
  ('BGN', 'Bulgarian Lev',       'Български лев',       'лв',  2),
  ('KWD', 'Kuwaiti Dinar',       'دينار كويتي',          'KD',  3),
  ('BHD', 'Bahraini Dinar',      'دينار بحريني',         'BD',  3);

INSERT INTO region_currency_defaults(region_code, ccy) VALUES
  ('US','USD'),('GB','GBP'),('IE','EUR'),('DE','EUR'),('FR','EUR'),
  ('IT','EUR'),('ES','EUR'),('NL','EUR'),('BE','EUR'),('AT','EUR'),
  ('PT','EUR'),('FI','EUR'),('GR','EUR'),('JP','JPY'),('IN','INR'),
  ('BR','BRL'),('CN','CNY'),('KR','KRW'),('MX','MXN'),('CA','CAD'),
  ('AU','AUD'),('CH','CHF'),('SE','SEK'),('NO','NOK'),('DK','DKK'),
  ('PL','PLN'),('TR','TRY'),('RU','RUB'),('UA','UAH'),('AE','AED'),
  ('SA','SAR'),('IL','ILS'),('EG','EGP'),('ZA','ZAR'),('NG','NGN'),
  ('TH','THB'),('VN','VND'),('ID','IDR'),('MY','MYR'),('PH','PHP'),
  ('SG','SGD'),('HK','HKD'),('TW','TWD'),('NZ','NZD'),('AR','ARS'),
  ('CL','CLP'),('CO','COP'),('PE','PEN'),('PK','PKR'),('BD','BDT'),
  ('LK','LKR'),('KE','KES'),('GH','GHS'),('MA','MAD'),('CZ','CZK'),
  ('HU','HUF'),('RO','RON'),('BG','BGN'),('KW','KWD'),('BH','BHD');

COMMIT;
```

```sql
-- down
BEGIN;
ALTER TABLE transactions
  DROP COLUMN IF EXISTS fx_rate_used,
  DROP COLUMN IF EXISTS displayed_amount,
  DROP COLUMN IF EXISTS displayed_currency;
ALTER TABLE profiles
  DROP COLUMN IF EXISTS region_code,
  DROP COLUMN IF EXISTS preferred_currency;
DROP TABLE IF EXISTS region_currency_defaults;
DROP TABLE IF EXISTS currency_rates;
DROP TABLE IF EXISTS currencies;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `fx:rate:<ccy>` | rate (string) | 25h |
| `fx:rates:all` | JSON map | 1h |
| `fx:age_seconds` | integer | 1h |
| `currency:catalog` | JSON list | 1h |

## 6. Search Index

Not used.

## 7. Vector Index

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- `currency_rates`: keep 90 days hot; archive monthly to R2 for analytics. We keep historical rates so we can render *the rate at the time of the transaction* on receipt screens.
- `currencies`: never drop a row; toggle `enabled=false` if we deprecate.
- `transactions.displayed_*` fields persist with the transaction for accounting/forensic use.

## 10. Sample Queries

```sql
-- Latest rate for a currency
SELECT rate, fetched_at, source
FROM currency_rates
WHERE ccy = $1
ORDER BY fetched_at DESC
LIMIT 1;

-- All latest rates (one query)
SELECT DISTINCT ON (ccy) ccy, rate, fetched_at
FROM currency_rates
ORDER BY ccy, fetched_at DESC;

-- Convert USD cents to display unit (math in app, not SQL, but reference)
-- display_amount_units = round(usd_cents / 100.0 * rate * 10^decimals) / 10^decimals

-- Rate freshness check (alert if any > 30h old)
SELECT ccy, NOW() - MAX(fetched_at) AS age
FROM currency_rates
GROUP BY ccy
HAVING NOW() - MAX(fetched_at) > INTERVAL '30 hours';

-- Distribution of users by preferred_currency
SELECT preferred_currency, COUNT(*) AS users
FROM profiles
WHERE preferred_currency IS NOT NULL
GROUP BY preferred_currency
ORDER BY users DESC;
```
