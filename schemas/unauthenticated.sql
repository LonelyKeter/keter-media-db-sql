--__Unauthenticated schema__--
DROP SCHEMA IF EXISTS unauthenticated CASCADE;
CREATE SCHEMA unauthenticated;
SET SCHEMA 'unauthenticated';

--MediaPublic
CREATE OR REPLACE VIEW Mediaproducts(Id, Title, Kind, AuthorId, AuthorName, AuthorCountry, Rating) AS
  SELECT M.Id, M.Title, M.Kind, U.Id, U.Login, A.Country, (M.Rating::real)
  FROM public.Mediaproducts M 
    INNER JOIN public.Users U 
    ON M.AuthorId = U.Id
    INNER JOIN public.Authors A
    ON A.Id = U.Id
  WHERE M.Public = TRUE;  

--MaterialsPublic
CREATE OR REPLACE VIEW Materials(Id, MediaId, Format, Quality, LicenseName) AS
  SELECT M.Id, M.MediaId, M.Format, M.Quality, L.Title
    FROM public.Materials M 
        INNER JOIN public.Licenses L 
        ON L.Id = M.LicenseId
    WHERE M.Id NOT IN (SELECT MaterialId FROM public.Administration);

CREATE OR REPLACE VIEW MaterialUsage(MaterialId, UserId, Date, LicenseId) AS
    SELECT MaterialId, UserId, Date, LicenseId 
    FROM public.MaterialUsage; 

--Users
CREATE OR REPLACE VIEW Users(Id, Name) AS 
    SELECT Id, Login 
    FROM public.Users;

--Authors
CREATE OR REPLACE VIEW Authors(Id, Name, Country) AS
 SELECT U.Id, U.Login, A.Country 
  FROM public.Users U
    INNER JOIN public.Authors A
    ON A.Id = U.Id;

CREATE OR REPLACE VIEW Tags(Tag, Popularity) AS  
  SELECT Tag, 5
  FROM public.Tags;

CREATE OR REPLACE VIEW Reviews(Id, MediaId, UserId, UserName, Rating, Text, Date) AS
  SELECT R.Id, R.MediaId, R.UserId, U.Login, R.Rating, R.Text, R.Date
  FROM public.TextReviews R 
    INNER JOIN public.Users U 
    ON R.UserId = U.Id
  WHERE R.Id NOT IN(SELECT ReviewId FROM public.Moderation);

CREATE OR REPLACE VIEW Licenses(Id, Title, Text, Date) AS
    SELECT Id, Title, Text, Date 
    FROM public.Licenses;