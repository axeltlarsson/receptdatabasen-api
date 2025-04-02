begin;

select
  *
from
  no_plan ();

select
  *
from
  check_test (views_are ('api', array['recipes', 'passkeys'], 'tables present'),
    true, 'all views are present
    in api schema', 'tables present', '');

select
  *
from
  check_test (functions_are ('api', array[
      'disabled', 'generate_authentication_options', 'generate_registration_options',
      'id_from_credential', 'insert_recipe', 'login', 'me', 'passkey_authentication_begin',
      'passkey_authentication_complete', 'passkey_registration_begin', 'passkey_registration_complete', 'refresh_token', 'search',
      'signup', 'update_recipe', 'verify_authentication_response', 'verify_registration_response'
    ], ' functions present'), true,
    'all functions are present in api schema', ' functions present', '');

select
  *
from
  finish ();

rollback;
