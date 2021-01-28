START TRANSACTION;

SET search_path = api, pg_catalog;

DROP FUNCTION login(text, text);
CREATE OR REPLACE FUNCTION login(user_name text, password text) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $_$
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
        'email', usr.email,
        'role', 'customer'
      ),
      'token', pgjwt.sign(
        json_build_object(
          'role', usr.role,
          'user_id', usr.id,
          'exp', extract(epoch from now())::integer + settings.get('jwt_lifetime')::int -- token expires in 1 hour
        ),
        settings.get('jwt_secret')
      )
    );
  end if;
end
$_$;

CREATE OR REPLACE FUNCTION me() RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $$
declare
    usr record;
begin

    select * from data."user"
    where id = request.user_id()
    into usr;

    return json_build_object(
        'id', usr.id,
        'user_name', usr.user_name,
        'email', usr.email,
        'role', usr.role
    );
end
$$;

REVOKE ALL ON TABLE recipes FROM anonymous;

SET search_path = data, pg_catalog;

DROP TRIGGER send_user_change_event ON "user";

ALTER TABLE "user"
	DROP CONSTRAINT user_name_check;

ALTER TABLE "user"
  RENAME COLUMN name TO user_name;

ALTER TABLE "user"
	ALTER COLUMN email DROP NOT NULL;

CREATE OR REPLACE FUNCTION encrypt_pass() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.password is not null then
    new.password = public.crypt(new.password, public.gen_salt('bf'));
  end if;
  return new;
end
$$;

ALTER TABLE "user"
	ADD CONSTRAINT user_user_name_check CHECK ((length(user_name) > 2));

ALTER TABLE "user"
	ADD CONSTRAINT user_user_name_key UNIQUE (user_name);

CREATE TRIGGER send_user_change_event
	AFTER INSERT OR UPDATE OR DELETE ON "user"
	FOR EACH ROW
	EXECUTE PROCEDURE rabbitmq.on_row_change('{"include":["id","user_name","email","role"]}');

revoke execute on function api.signup(text,text,text) from anonymous;
revoke execute on function api.refresh_token() from webuser;
revoke execute on function api.search(text) from anonymous;
COMMIT TRANSACTION;
