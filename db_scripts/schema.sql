CREATE SCHEMA api;

CREATE TABLE api.recipes(
  id            SERIAL PRIMARY KEY,
  title         TEXT NOT NULL UNIQUE,
  description   TEXT,
  instructions  TEXT NOT NULL,
  tags          TEXT[],
  quantity      INTEGER,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
