--__Update schema__--
DROP SCHEMA IF EXISTS update CASCADE;
CREATE SCHEMA update;
SET SCHEMA 'update';

CREATE OR REPLACE FUNCTION update_ratings() RETURNS void
AS $$
BEGIN
    WITH ratings AS (
        SELECT 
            material_id, 
            AVG(rating) AS rating 
        FROM public.material_usage
        GROUP BY material_id
    )
    UPDATE public.materials
        SET rating = r.rating
        FROM ratings r
        WHERE id = r.material_id;


    WITH ratings AS (
        SELECT 
            media_id, 
            AVG(rating) AS rating 
        FROM public.materials
        GROUP BY media_id
    )
    UPDATE public.mediaproducts
        SET rating = r.rating
        FROM ratings r
        WHERE id = r.media_id;


    WITH ratings AS (
        SELECT 
            author_id, 
            AVG(rating) AS rating 
        FROM public.mediaproducts
        GROUP BY author_id
    )
    UPDATE public.authors
        SET rating = r.rating
        FROM ratings r
        WHERE id = r.author_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_use_count() RETURNS void
AS $$
BEGIN
    WITH use_counts AS (
        SELECT 
            material_id, 
            COUNT(*) AS use_count
        FROM public.material_usage
        GROUP BY material_id
    )
    UPDATE public.materials
        SET use_count = u.use_count
        FROM use_counts u
        WHERE id = u.material_id;

    WITH use_counts AS (
        SELECT 
            media_id, 
            SUM(use_count) as use_count
        FROM public.materials
        GROUP BY media_id
    )
    UPDATE public.mediaproducts
        SET use_count = u.use_count
        FROM use_counts u
        WHERE id = u.media_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;