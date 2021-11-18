--__Update schema__--
DROP SCHEMA IF EXISTS update CASCADE;
CREATE SCHEMA update;
SET SCHEMA 'update';

CREATE OR REPLACE FUNCTION UpdateRatings() RETURNS void
AS $$
BEGIN
    WITH Ratings AS (
        SELECT MaterialId, AVG(Rating) as Rating 
            FROM public.MaterialUsage
            GROUP BY MaterialId)
    UPDATE public.Materials
        SET Rating = R.Rating
        FROM Ratings R
        WHERE Id = R.MaterialId;

    WITH Ratings AS (
        SELECT MediaId, AVG(Rating) as Rating 
            FROM public.Materials
            GROUP BY MediaId)
    UPDATE public.Mediaproducts
        SET Rating = R.Rating
        FROM Ratings R
        WHERE Id = R.MediaId;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION UpdateUseCount() RETURNS void
AS $$
BEGIN
    WITH UseCounts AS (
        SELECT MaterialId, COUNT(*) as UseCount
            FROM public.MaterialUsage
            GROUP BY MaterialId)
    UPDATE public.Materials
        SET UseCount = U.UseCount
        FROM UseCounts U
        WHERE Id = U.MaterialId;

    WITH UseCounts AS (
        SELECT MediaId, SUM(UseCount) as UseCount
            FROM public.Materials
            GROUP BY MediaId)
    UPDATE public.Mediaproducts
        SET UseCount = U.UseCount
        FROM UseCounts U
        WHERE Id = U.MediaId;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;