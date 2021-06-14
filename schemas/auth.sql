DROP SCHEMA IF EXISTS auth CASCADE;
CREATE SCHEMA auth;
SET SCHEMA 'auth';

CREATE VIEW Users(Id, Login, Password, Email, Author, Moderator, Administrator) AS
  SELECT Id, Login, Password, Email, Author, Moderator, Administrator
  FROM public.Users;

CREATE OR REPLACE FUNCTION 
  RegisterUser(login Users.Login%TYPE, password Users.Password%TYPE, email VARCHAR) returns Users.Id%TYPE 
  AS $$
    DECLARE
		new_id Users.Id%TYPE;
		BEGIN
			INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
        VALUES (login, password, email, FALSE, FALSE, FALSE)
        RETURNING Id
        INTO STRICT new_id;
      RETURN new_id;
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

