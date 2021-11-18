--__Author schema__--
DROP SCHEMA IF EXISTS author CASCADE;
CREATE SCHEMA author;
SET SCHEMA 'author';

CREATE OR REPLACE FUNCTION CreateMedia(
    user_id public.Users.Id%TYPE,
    media_title public.Mediaproducts.Title%TYPE,
    media_kind public.Mediaproducts.Kind%TYPE
)
RETURNS public.Mediaproducts.Id%TYPE 
AS $$
    DECLARE
        created_media_id public.Mediaproducts.Id%TYPE;
    BEGIN
        IF user_id NOT IN(SELECT Id FROM public.Authors) THEN 
            RAISE EXCEPTION 'User creating material shoud be author';
        END IF;

        INSERT INTO public.Mediaproducts(AuthorId, Title, Kind, Date)
            VALUES(user_id, media_title, media_kind, current_date)
            RETURNING Id INTO STRICT created_media_id;

        RETURN created_media_id;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION AddMaterial(
  user_id public.Users.Id%TYPE,
  media_id public.Mediaproducts.Id%TYPE, 
  license_id public.Licenses.Id%TYPE,
  format public.Materials.Format%TYPE,
  quality public.Materials.Quality%TYPE
)
RETURNS public.Materials.Id%TYPE
  AS $$
    DECLARE
        added_material_id public.Materials.Id%TYPE;
        required_user_id public.Users.Id%TYPE;
	BEGIN
        SELECT AuthorId INTO STRICT required_user_id
            FROM public.Mediaproducts
            WHERE Id = media_id;

        IF user_id = required_user_id THEN
            BEGIN
                INSERT INTO public.Materials(MediaId, LicenseId, Format, Quality)
                    VALUES (media_id, license_id, format, quality)
                RETURNING Id INTO STRICT added_material_id;
            END;
        ELSE 
            RAISE EXCEPTION 'User_id doesn''t match';
        END IF;
        
        RETURN added_material_id;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION DeleteMaterial(
  user_id public.Users.Id%TYPE,
  material_id public.Materials.Id%TYPE)
  RETURNS void
  AS $$
    DECLARE
        id public.Materials.Id%TYPE;
        required_user_id public.Users.Id%TYPE;
	BEGIN
        SELECT AuthorId INTO STRICT required_user_id
            FROM public.Mediaproducts
            WHERE Id = media_id;

        IF user_id = required_user_id THEN
            DELETE FROM public.Materials
                WHERE Id = material_id;
        ELSE 
            RAISE EXCEPTION 'User_id doesn''t match';
        END IF;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;