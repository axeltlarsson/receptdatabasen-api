START TRANSACTION;

SET search_path = api, pg_catalog;

drop function if exists login(text, text);
CREATE OR REPLACE FUNCTION login(email text, password text) RETURNS json
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    AS $_$
declare
usr record;
begin

  select * from data."user" as u
  where u.email = $1 and u.password = public.crypt($2, u.password)
  INTO usr;

  if usr is NULL then
    raise exception 'invalid email/password';
  else

    return json_build_object(
      'me', json_build_object(
        'id', usr.id,
        'name', usr.name,
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
        'name', usr.name,
        'email', usr.email,
        'role', usr.role
    );
end
$$;

REVOKE ALL ON TABLE recipes FROM anonymous;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE recipes TO anonymous;

SET search_path = data, pg_catalog;

DROP TRIGGER send_user_change_event ON "user";

ALTER TABLE "user"
	DROP CONSTRAINT user_user_name_check;

ALTER TABLE "user"
	DROP CONSTRAINT user_user_name_key;

ALTER TABLE "user"
  RENAME COLUMN user_name TO name;
ALTER TABLE "user"
	ALTER COLUMN email SET NOT NULL;

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
	ADD CONSTRAINT user_name_check CHECK ((length(name) > 2));

CREATE TRIGGER send_user_change_event
	AFTER INSERT OR UPDATE OR DELETE ON "user"
	FOR EACH ROW
	EXECUTE PROCEDURE rabbitmq.on_row_change('{"include":["id","name","email","role"]}');

COMMIT TRANSACTION;
