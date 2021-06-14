--__Public schema__--
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
SET SCHEMA 'public';

--TYPES AND DOMAINS
CREATE TABLE Countries(
	Id VARCHAR(2) PRIMARY KEY,
	FullName VARCHAR NOT NULL);

CREATE UNIQUE INDEX CountriesIndex ON Countries(Id);

CREATE DOMAIN EMAIL VARCHAR
	CHECK(VALUE ~ '^.+@(.{2,}\.)+.{2,}$');

CREATE DOMAIN HTTPLINK VARCHAR
	CHECK(VALUE ~ '^https?\/\/(www\.)?([a-z0-9\-]+\.?)+(\/[a-z0-9\-]+)+(\?.*)?$');

CREATE DOMAIN FORMAT VARCHAR 
	CHECK(VALUE ~ '^\..+$');

CREATE DOMAIN MEDIAKIND CHAR(5)
	CHECK(VALUE IN('Audio', 'Video', 'Image'));

CREATE DOMAIN ALIAS AS VARCHAR(25)
	CHECK(VALUE ~ '^(\w+\s*)+$');

CREATE TYPE QUALITY as ENUM('VERY LOW', 'LOW', 'MEDIUM', 'HIGH', 'VERY HIGH');
CREATE TYPE PREVIEWSIZE as ENUM('SMALL', 'MEDIUM', 'LARGE');


--Authentication and user data
CREATE TABLE Users(
  Id SERIAL PRIMARY KEY CHECK(Id>0),
  Login VARCHAR(20) UNIQUE NOT NULL,
  Password BYTEA NOT NULL,
  Email EMAIL NOT NULL UNIQUE,
  Author BOOLEAN,
  Moderator BOOLEAN,
  Administrator BOOLEAN);

--Mediaproducts and Materials
CREATE TABLE Authors(
	Id SERIAL PRIMARY KEY REFERENCES Users,
	Country VARCHAR(2) NOT NULL REFERENCES Countries ON UPDATE CASCADE ON DELETE RESTRICT);

CREATE TABLE Mediaproducts(
	Id SERIAL PRIMARY KEY Check(Id>0),
  Public BOOLEAN NOT NULL,
	Title VARCHAR(30) NOT NULL,
	AuthorId INT REFERENCES Authors ON DELETE CASCADE,
	Kind MEDIAKIND NOT NULL,
	Date DATE NOT NULL,
	Rating NUMERIC(1000, 999) CHECK(Rating >= 0 AND Rating <= 10));

CREATE TABLE Coauthors(
	CoauthorId INT REFERENCES Authors ON UPDATE CASCADE ON DELETE CASCADE,
	MediaId INT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	PRIMARY KEY(CoauthorId, MediaId));

CREATE TABLE Tags(
	Id SERIAL PRIMARY KEY,
	Tag VARCHAR(12) NOT NULL UNIQUE
  --,Popularity NUMERIC(1000, 999) CHECK(VALUE >= 0 AND VALUE <= 10))
  );

CREATE TABLE MediaTags(
	MediaId INT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	TagId INT REFERENCES Tags ON UPDATE CASCADE ON DELETE RESTRICT,
	PRIMARY KEY(MediaId, TagId));

CREATE TABLE Licenses(
	Id SERIAL PRIMARY KEY,
	Title CHAR(20) NOT NULL UNIQUE,
	Text TEXT NOT NULL,
	Date DATE NOT NULL,
	Relevance BOOLEAN NOT NULL DEFAULT True,
	Substitution INT DEFAULT 1 REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT);

CREATE TABLE Materials(
	Id SERIAL PRIMARY KEY,
	MediaId INT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
  Public BOOLEAN NOT NULL,
	Format FORMAT NOT NULL,
	Quality QUALITY NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT DEFAULT 1,
	DownloadLink HTTPLINK NOT NULL);

CREATE TABLE Previews(
	Id SERIAL PRIMARY KEY,
	MediaId INT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	MaterialId INT REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE);

CREATE TABLE MaterialUsage(
	MaterialId INT NOT NULL REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE,
	UserId INT NOT NULL REFERENCES Users ON UPDATE CASCADE ON DELETE CASCADE,
	Date DATE NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT,
  PRIMARY KEY(MaterialId, UserId));

CREATE TABLE Reviews(
	Id SERIAL PRIMARY KEY,
	MediaId INT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	UserId INT NOT NULL REFERENCES Users,
	Rating SMALLINT NOT NULL CHECK(Rating > 0 AND RATING <= 10),
	Text TEXT,
	Date DATE NOT NULL);

CREATE TABLE ModerationReasons(
	Id SERIAL PRIMARY KEY,
	Text TEXT NOT NULL);

CREATE TABLE Moderation(
  MederatorId INT NOT NULL REFERENCES Users,
	ReviewId INT PRIMARY KEY REFERENCES Reviews ON UPDATE CASCADE ON DELETE CASCADE,
	ReasonId INT NOT NULL REFERENCES ModerationReasons ON UPDATE CASCADE ON DELETE RESTRICT,
  Date DATE NOT NULL);

CREATE TABLE AdministrationReasons(
	Id SERIAL PRIMARY KEY,
	Text TEXT NOT NULL);

CREATE TABLE Administration(
  AdminId INT NOT NULL REFERENCES Users,
	MaterialId INT PRIMARY KEY REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE,
	ReasonId INT REFERENCES AdministrationReasons ON UPDATE CASCADE ON DELETE RESTRICT,
  Date DATE NOT NULL);


DROP SCHEMA IF EXISTS auth CASCADE;
CREATE SCHEMA auth;
SET SCHEMA 'auth';

CREATE VIEW Users(Id, Login, Password, Email, Author, Moderator, Administrator) AS
  SELECT Id, Login, Password, Email, Author, Moderator, Administrator
  FROM public.Users;

CREATE OR REPLACE FUNCTION 
  RegisterUser(login Users.Login%TYPE, password Users.Password%TYPE, email VARCHAR) returns Users.Id%TYPE 
  AS $$
    DECLARE
		new_id Users.Id%TYPE;
		BEGIN
			INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
        VALUES (login, password, email, FALSE, FALSE, FALSE)
        RETURNING Id
        INTO STRICT new_id;
      RETURN new_id;
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

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


--__Registered schema__--
DROP SCHEMA IF EXISTS registered CASCADE;
CREATE SCHEMA registered;
SET SCHEMA 'registered';

CREATE OR REPLACE VIEW Users(Id, Name, Author, Moderator, Administrator) AS
  SELECT Id, Login, Author, Moderator, Administrator
    FROM public.Users;

CREATE OR REPLACE FUNCTION PostReview(
  user_id Users.Id%TYPE, 
  media_id public.Mediaproducts.Id%TYPE, 
  rating SMALLINT,
  text TEXT)
  RETURNS void
  AS $$
		BEGIN
			INSERT INTO public.Reviews(MediaId, UserId, Rating, Text, Date)
        VALUES (media_id, user_id, rating, text, current_date);
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION PostReview(
  user_id Users.Id%TYPE, 
  title public.Mediaproducts.Title%TYPE,
  author public.Users.Login%TYPE,
  rating SMALLINT,
  text TEXT)
  RETURNS void
  AS $$
    DECLARE
      media_id public.Mediaproducts.Id%TYPE;
		BEGIN
      SELECT Id INTO STRICT media_id 
        FROM public.Mediaproducts M JOIN public.Users U 
        ON M.AuthorId = U.Id 
        WHERE (M.Title = title AND U.Login = author);

			INSERT INTO public.Reviews(MediaId, UserId, Rating, Text, Date)
        VALUES (media_id, user_id, rating, text, current_date);
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;--__Author schema__--
DROP SCHEMA IF EXISTS author CASCADE;
CREATE SCHEMA author;
SET SCHEMA 'author';

--__Moderator schema__--
DROP SCHEMA IF EXISTS moderator CASCADE;
CREATE SCHEMA moderator;
SET SCHEMA 'moderator';

--__Admin schema__--
DROP SCHEMA IF EXISTS admin CASCADE;
CREATE SCHEMA admin;
SET SCHEMA 'admin';

