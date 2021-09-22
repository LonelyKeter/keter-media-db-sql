--__Registered schema__--
DROP SCHEMA IF EXISTS registered CASCADE;
CREATE SCHEMA registered;
SET SCHEMA 'registered';

CREATE OR REPLACE VIEW MaterialUsage(MaterialId, UserId, Date, LicenseId) AS
    SELECT MaterialId, UserId, Date, LicenseId 
    FROM public.MaterialUsage; 

CREATE OR REPLACE VIEW Users(Id, Name, Author, Moderator, Administrator) AS
  SELECT Id, Login, Author, Moderator, Administrator
    FROM public.Users;

CREATE OR REPLACE FUNCTION PostReview(
  user_id Users.Id%TYPE, 
  media_id public.Mediaproducts.Id%TYPE, 
  rating SMALLINT,
  text TEXT)
  RETURNS void
  AS $$
		BEGIN
			INSERT INTO public.Reviews(MediaId, UserId, Rating, Text, Date)
                VALUES (media_id, user_id, rating, text, current_date);
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION PostReview(
  user_id Users.Id%TYPE, 
  title public.Mediaproducts.Title%TYPE,
  author public.Users.Login%TYPE,
  rating SMALLINT,
  text TEXT)
  RETURNS void
  AS $$
    DECLARE
      media_id public.Mediaproducts.Id%TYPE;
		BEGIN
      SELECT Id INTO STRICT media_id 
        FROM public.Mediaproducts M JOIN public.Users U 
        ON M.AuthorId = U.Id 
        WHERE (M.Title = title AND U.Login = author);

			INSERT INTO public.Reviews(MediaId, UserId, Rating, Text, Date)
        VALUES (media_id, user_id, rating, text, current_date);
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;