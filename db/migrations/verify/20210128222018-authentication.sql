-- Verify app:20210128222018-authentication on pg

BEGIN;

SELECT has_function_privilege('api.login(text, text)', 'execute');

ROLLBACK;
