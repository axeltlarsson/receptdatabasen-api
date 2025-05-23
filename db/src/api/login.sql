create or replace function login(user_name text, password text) returns json as $$
declare
usr record;
begin

  select * from data."user" as u
  where u.user_name = $1 and u.password = public.crypt($2, u.password)
  INTO usr;

  if usr is NULL then
    raise "insufficient_privilege";
  else

    return json_build_object(
      'me', json_build_object(
        'id', usr.id,
        'user_name', usr.user_name,
        'email', usr.email
      ),
      'token', pgjwt.sign(
        json_build_object(
          'role', usr.role,
          'user_id', usr.id,
          'exp', extract(epoch from now())::integer + settings.get('jwt_lifetime')::int
        ),
        settings.get('jwt_secret')
      )
    );
  end if;
end
$$ stable security definer language plpgsql;
-- by default all functions are accessible to the public, we need to remove that and define our specific access rules
revoke all privileges on function login(text, text) from public;
