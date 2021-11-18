--__Registered schema__--
DROP SCHEMA IF EXISTS registered CASCADE;
CREATE SCHEMA registered;
SET SCHEMA 'registered';

CREATE OR REPLACE FUNCTION PostReview(
  user_id public.Users.Id%TYPE, 
  media_id public.Mediaproducts.Id%TYPE, 
  text TEXT)
  RETURNS void
  AS $$
		BEGIN
			INSERT INTO public.Reviews(MediaId, UserId, Text, Date)
                VALUES (media_id, user_id, text, current_date);
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION PostReview(
  user_id public.Users.Id%TYPE, 
  title public.Mediaproducts.Title%TYPE,
  author public.Users.Login%TYPE,
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

	    INSERT INTO public.Reviews(MediaId, UserId, Text, Date)
          VALUES (media_id, user_id, text, current_date);
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION CreateMaterialUsage(
  user_id public.Users.Id%TYPE, 
  material_id public.Materials.Id%TYPE)
  RETURNS void
  AS $$
    DECLARE
        license_id public.Licenses.Id%TYPE;
		BEGIN
            SELECT LicenseId INTO STRICT license_id
                FROM public.Materials 
                WHERE Id = material_id;

			INSERT INTO public.MaterialUsage(MaterialId, UserId, Date, LicenseId)
                VALUES (material_id, user_id, current_date, license_id);
		END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION UpdateMaterialRating(
  material_id public.Materials.Id%TYPE,
  user_id public.Users.Id%TYPE,
  input_rating public.MaterialUsage.Rating%TYPE)
  RETURNS void
  AS $$
	BEGIN
        IF input_rating IS NULL THEN
            RAISE EXCEPTION 'Rating cannot be NULL';
        END IF;

		UPDATE public.MaterialUsage
            SET Rating = input_rating
            WHERE MaterialId = material_id AND UserId = user_id;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;
