create or replace view api.passkeys as (
  select
    id,
    public_key,
    updated_at,
    created_at
  from data.passkey
);

alter view api.passkeys owner to api;
