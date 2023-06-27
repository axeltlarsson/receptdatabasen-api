CREATE TABLE passkey (
    id SERIAL PRIMARY KEY,
    user_id INTEGER not null REFERENCES data.user(id),
    public_key TEXT not null,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

create trigger passkey_set_updated_at_timestamp
  before update on data.passkey for each row
  execute procedure set_updated_at_timestamp ();
