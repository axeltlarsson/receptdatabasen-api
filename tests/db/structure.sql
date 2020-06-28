begin;

select
  *
from
  no_plan ();

select
  *
from
  check_test (views_are ('api', array['recipes'], 'tables present'), true, 'all views are present
    in api schema', 'tables present', '');

select
  *
from
  check_test (functions_are ('api', array['login', 'signup', 'refresh_token', 'me', 'search',
    'insert_recipe', 'update_recipe'], 'functions present'), true, 'all functions are present in
    api
    schema', 'functions present', '');

select
  *
from
  finish ();

rollback;
