DROP SCHEMA IF EXISTS auth CASCADE;
CREATE SCHEMA auth;
SET SCHEMA 'auth';

CREATE VIEW users(
    id, 
    login, 
    password, 
    email, 
    is_author, 
    administration_permissions
) AS
SELECT 
    id, 
    login, 
    password, 
    email, 
    id IN (SELECT id FROM public.authors), 
    administration_permissions 
FROM public.users;

CREATE OR REPLACE FUNCTION 
  register_user(login users.login%TYPE, password users.password%TYPE, email VARCHAR) returns users.id%TYPE 
  AS $$
    DECLARE
		new_id users.id%TYPE;
	BEGIN
		INSERT INTO public.users(login, password, email)
            VALUES(login, password, email)
        RETURNING Id
        INTO STRICT new_id;

        RETURN new_id;
	END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

