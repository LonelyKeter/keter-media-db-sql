--__Unauthenticated schema__--
DROP SCHEMA IF EXISTS unauthenticated CASCADE;
CREATE SCHEMA unauthenticated;
SET SCHEMA 'unauthenticated';

--MediaPublic Процедура, возвращающая таблицу
CREATE OR REPLACE VIEW Mediaproducts(Id, Title, Kind, AuthorName, AuthorCountry) AS
  SELECT M.Id, M.Title, M.Kind, U.Login, A.Country
  FROM public.Mediaproducts M, public.Users U, public.Authors A
  WHERE (A.Id = M.AuthorId AND U.Id = A.Id AND M.Public = TRUE);  

--MaterialsPublic
CREATE OR REPLACE VIEW Materials(MediaId, MaterialId, Format, Quality, LicenseName, DownloadLink) AS
  SELECT M.MediaId, M.Id, M.Format, M.Quality, L.Title, M.DownloadLink
    FROM public.Materials M, public.Licenses L 
    WHERE M.LicenseId = L.Id;

--Authors
CREATE OR REPLACE VIEW Authors(Name, Country) AS
 SELECT U.Login, A.Country 
  FROM public.Users U, public.Authors A
  WHERE A.Id = U.Id;

CREATE OR REPLACE VIEW Tags(Tag, Popularity) AS  
  SELECT Tag, 5
  FROM public.Tags;

CREATE OR REPLACE VIEW PublicReviews(MediaId, UserId, UserName, Rating, Text) AS
  SELECT R.MediaId, R.UserId, U.Login, R.Rating, R.Text 
  FROM public.Reviews R, public.Users U, public.Moderation Mod
  WHERE R.Id NOT IN (Mod.ReviewId); 


