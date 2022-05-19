--__Registered schema__--
DROP SCHEMA IF EXISTS registered CASCADE;
CREATE SCHEMA registered;
SET SCHEMA 'registered';

CREATE OR REPLACE FUNCTION post_review(
  user_id   public.users.Id%TYPE, 
  media_id  public.mediaproducts.Id%TYPE, 
  text      TEXT)
RETURNS void
  AS $$
	BEGIN
		INSERT INTO public.reviews(
            media_id, 
            user_id, 
            text, 
            date)
        VALUES (
            media_id, 
            user_id, 
            text, 
            current_date);
	END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION post_review(
  user_id   public.users.id%TYPE, 
  title     public.mediaproducts.title%TYPE,
  author    public.users.login%TYPE,
  text TEXT)
  RETURNS void
  AS $$
    DECLARE
      media_id  public.mediaproducts.id%TYPE;
	BEGIN
        SELECT 
            id 
        INTO STRICT 
            media_id
        FROM public.mediaproducts m JOIN public.users u 
            ON m.author_id = u.id 
        WHERE (M.Title = title AND U.Login = author);

	    INSERT INTO public.reviews(
            media_id, 
            user_id, 
            text, 
            date)
        VALUES (
            media_id, 
            user_id, 
            text, 
            current_date);
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION create_material_usage(
  user_id       public.users.id%TYPE, 
  material_id   public.materials.id%TYPE)
  RETURNS void
  AS $$
    DECLARE
    v_license_id public.licenses.id%TYPE;
	BEGIN
        SELECT license_id INTO STRICT v_license_id
            FROM public.materials 
            WHERE id = material_id;

		INSERT INTO public.material_usage(material_id, user_id, date, license_id)
            VALUES (material_id, user_id, current_date, v_license_id);
		END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_material_rating(
  v_material_id   public.materials.id%TYPE,
  v_user_id       public.users.id%TYPE,
  v_rating        public.material_usage.rating%TYPE)
  RETURNS void
  AS $$
	BEGIN
        IF v_rating IS NULL THEN
            RAISE EXCEPTION 'Rating cannot be NULL';
        END IF;

		UPDATE public.material_usage
            SET rating = v_rating
            WHERE material_id = v_material_id AND user_id = v_user_id;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;
