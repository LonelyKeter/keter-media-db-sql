--__Unauthenticated schema__--
DROP SCHEMA IF EXISTS unauthenticated CASCADE;
CREATE SCHEMA unauthenticated;
SET SCHEMA 'unauthenticated';

--MediaPublic
CREATE OR REPLACE VIEW Mediaproducts(Id, Title, Kind, AuthorId, AuthorName, AuthorCountry, Rating) AS
  SELECT M.Id, M.Title, M.Kind, U.Id, U.Login, A.Country, (M.Rating::real)
  FROM public.Mediaproducts M, public.Users U, public.Authors A
  WHERE (A.Id = M.AuthorId AND U.Id = A.Id AND M.Public = TRUE);  

--MaterialsPublic
CREATE OR REPLACE VIEW Materials(MediaId, MaterialId, Format, Quality, Size, LicenseName, DownloadLink) AS
  SELECT M.MediaId, M.Id, M.Format, M.Quality, M.Size, L.Title, M.DownloadLink
    FROM public.Materials M, public.Licenses L 
    WHERE M.LicenseId = L.Id;

--Authors
CREATE OR REPLACE VIEW Authors(Id, Name, Country) AS
 SELECT U.Id, U.Login, A.Country 
  FROM public.Users U, public.Authors A
  WHERE A.Id = U.Id;

CREATE OR REPLACE VIEW Tags(Tag, Popularity) AS  
  SELECT Tag, 5
  FROM public.Tags;

CREATE OR REPLACE VIEW Reviews(MediaId, UserId, UserName, Rating, Text, Date) AS
  SELECT R.MediaId, R.UserId, U.Login, R.Rating, R.Text, R.Date
  FROM public.TextReviews R, public.Users U, public.Moderation Mod
  WHERE (R.Id NOT IN (Mod.ReviewId));


