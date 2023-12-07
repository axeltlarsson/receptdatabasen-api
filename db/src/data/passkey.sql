CREATE TABLE passkey (
    id SERIAL PRIMARY KEY,
    user_id INTEGER not null REFERENCES data.user(id),
    data json not null,
    name text not null,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_used_at TIMESTAMPTZ
);

create trigger passkey_set_updated_at_timestamp
  before update on data.passkey for each row
  execute procedure set_updated_at_timestamp ();

grant select, insert, update, delete on data.passkey to api;


alter table passkey enable row level security;
create policy users_access_own_passkeys on passkey
    using (user_id = request.user_id());
