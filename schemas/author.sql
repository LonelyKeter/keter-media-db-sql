--__Author schema__--
DROP SCHEMA IF EXISTS author CASCADE;
CREATE SCHEMA author;
SET SCHEMA 'author';

CREATE OR REPLACE FUNCTION create_media(
    user_id     public.users.id%TYPE,
    media_title public.mediaproducts.title%TYPE,
    media_kind  public.mediaproducts.kind%TYPE
)
RETURNS public.mediaproducts.id%TYPE 
AS $$
    DECLARE
        created_media_id public.mediaproducts.id%TYPE;
    BEGIN
        IF user_id NOT IN(SELECT id FROM public.authors) THEN 
            RAISE EXCEPTION 'User creating material shoud be author';
        END IF;

        INSERT INTO public.mediaproducts(author_id, title, kind, date)
            VALUES(user_id, media_title, media_kind, current_date)
            RETURNING id 
            INTO STRICT created_media_id;

        RETURN created_media_id;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION add_material(
  user_id       public.users.Id%TYPE,
  media_id      public.mediaproducts.id%TYPE, 
  license_id    public.licenses.id%TYPE,
  format        public.materials.format%TYPE,
  quality       public.materials.quality%TYPE
)
RETURNS public.materials.id%TYPE
  AS $$
    DECLARE
        added_material_id   public.materials.id%TYPE;
        required_user_id    public.users.id%TYPE;
	BEGIN
        SELECT AuthorId INTO STRICT required_user_id
            FROM public.mediaproducts
            WHERE Id = media_id;

        IF user_id = required_user_id THEN
            BEGIN
                INSERT INTO public.materials(media_id, license_id, format, quality)
                    VALUES (media_id, license_id, format, quality)
                RETURNING Id INTO STRICT added_material_id;
            END;
        ELSE 
            RAISE EXCEPTION 'user_id doesn''t match';
        END IF;
        
        RETURN added_material_id;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_material(
  user_id       public.users.id%TYPE,
  material_id   public.materials.id%TYPE)
  RETURNS void
  AS $$
    DECLARE
        id                  public.materials.id%TYPE;
        required_user_id    public.users.id%TYPE;
	BEGIN
        SELECT author_id INTO STRICT required_user_id
            FROM public.mediaproducts
            WHERE id = media_id;

        IF user_id = required_user_id THEN
            DELETE FROM public.materials
                WHERE id = material_id;
        ELSE 
            RAISE EXCEPTION 'user_id doesn''t match';
        END IF;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;