--__Admin schema__--
DROP SCHEMA IF EXISTS admin CASCADE;
CREATE SCHEMA admin;
SET SCHEMA 'admin';

CREATE OR REPLACE VIEW administration(
    admin_id,
    admin_name,
    media_id,
    media_title,
    author_id,
    author_name,
    reason_id,
    reason_text,
    date
) AS 
SELECT
    a.admin_id,
    adm.login,
    mp.id,
    mp.title,
    u.id,
    u.login,
    ar.id,
    ar.text,
    a.date
FROM public.administration a
INNER JOIN public.administration_reasons ar
    ON a.reason_id = ar.id
INNER JOIN public.mediaproducts mp
    ON a.media_id = mp.id
INNER JOIN public.users u 
    ON mp.author_id = u.id
INNER JOIN (
    SELECT id, login
    FROM public.users) AS adm
    ON a.admin_id = adm.id;

CREATE OR REPLACE FUNCTION insert_administration(
    admin_id    public.users.id%TYPE, 
    media_id    public.mediaproducts.id%TYPE, 
    reason_id   public.administration_reasons.id%TYPE)
RETURNS public.mediaproducts.id%TYPE
AS $$
BEGIN
    INSERT INTO public.administration(admin_id, media_id, reason_id, date)
        VALUES(admin_id, media_id, reason_id, current_date);
    
    RETURN media_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 