--__Unauthenticated schema__--
DROP SCHEMA IF EXISTS unauthenticated CASCADE;
CREATE SCHEMA unauthenticated;
SET SCHEMA 'unauthenticated';

--MediaPublic
CREATE OR REPLACE VIEW mediaproducts(
    id, 
    title, 
    kind, 
    author_id, 
    author_name, 
    author_country, 
    rating, 
    use_count
) AS
SELECT 
    m.id, 
    m.title,
    m.kind, 
    u.id, 
    u.login, 
    a.country, 
    (m.rating::real), 
    m.use_count
FROM public.mediaproducts m 
INNER JOIN public.users u 
    ON m.author_id = u.id
INNER JOIN public.authors a
    ON a.id = u.id
WHERE m.public = TRUE;  

--MaterialsPublic
CREATE OR REPLACE VIEW materials(
    id, 
    media_id, 
    format, 
    quality, 
    license_name, 
    rating, 
    use_count, 
    download_name
) AS
SELECT 
    m.id, 
    m.media_id, 
    m.format, 
    m.quality, 
    l.title, 
    (m.rating::real), 
    m.use_count, 
    download_name
FROM public.materials m 
INNER JOIN public.licenses l 
    ON l.id = m.license_id
WHERE m.id NOT IN (SELECT material_id FROM public.administration);


CREATE OR REPLACE VIEW material_usage(
    material_id, 
    user_id, 
    date, 
    license_id, 
    rating
) AS
SELECT 
    material_id, 
    user_id, 
    date, 
    license_id,
    rating
FROM public.material_usage; 

--Users
CREATE OR REPLACE VIEW users(
    id, 
    name, 
    is_author, 
    administration_permissions
) AS 
SELECT 
    id, 
    login, 
    id IN (SELECT id FROM public.authors), 
    administration_permissions 
FROM public.users;

--Authors
CREATE OR REPLACE VIEW authors(
    id, 
    name, 
    country
) AS
SELECT 
    u.id, 
    u.login, 
    a.country 
FROM public.users u
INNER JOIN public.authors a
    ON a.id = u.id;

CREATE OR REPLACE VIEW reviews(
    id, 
    media_id, 
    user_id, 
    user_name, 
    text, 
    date
) AS
SELECT 
    r.id, 
    r.media_id, 
    r.user_id, 
    u.login, 
    r.text, 
    r.date
FROM public.reviews r 
INNER JOIN public.users u 
    ON r.user_id = u.id
WHERE r.id NOT IN(SELECT review_id FROM public.moderation);

CREATE OR REPLACE VIEW licenses(
    id, 
    title, 
    text, 
    date
) AS
SELECT 
    id, 
    title, 
    text, 
    date 
FROM public.licenses;