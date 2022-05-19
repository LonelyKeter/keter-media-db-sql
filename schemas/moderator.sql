--__Moderator schema__--
DROP SCHEMA IF EXISTS moderator CASCADE;
CREATE SCHEMA moderator;
SET SCHEMA 'moderator';

CREATE OR REPLACE VIEW moderation(
    moderator_id,
    moderator_name,
    review_id,
    review_text,
    review_date,
    user_id,
    user_name,
    media_id,
    media_title,
    reason_id,
    reason_text,
    date
) AS 
SELECT
    m.moderator_id,
    mod.login,
    rev.id,
    rev.text,
    rev.date,
    rev.user_id,
    u.login,
    mp.id,
    mp.title,
    mr.id,
    mr.text,
    m.date
FROM public.moderation m
INNER JOIN public.moderation_reasons mr
    ON m.reason_id = mr.id
INNER JOIN public.reviews rev
    ON m.review_id = rev.id
INNER JOIN public.mediaproducts mp
    ON rev.media_id = mp.id
INNER JOIN public.users u 
    ON rev.user_id = u.id
INNER JOIN (
    SELECT id, login
    FROM public.users) AS mod
    ON m.moderator_id = mod.id;

CREATE OR REPLACE FUNCTION insert_moderation(
    moderator_id    public.users.id%TYPE, 
    review_id       public.reviews.id%TYPE, 
    reason_id       public.moderation_reasons.id%TYPE)
RETURNS public.reviews.id%TYPE
AS $$
BEGIN
    IF moderator_id NOT IN(
        SELECT id 
        FROM public.users 
        WHERE administration_permissions >= 'moderator'
    ) THEN
        RAISE EXCEPTION 'Not enough permissions for moderating';
    END IF;

    INSERT INTO public.moderation(moderator_id, review_id, reason_id, date)
        VALUES(moderator_id, review_id, reason_id, current_date);
    
    RETURN review_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
