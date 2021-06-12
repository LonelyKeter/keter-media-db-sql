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
	Text TEXT,
	Rating INT NOT NULL CHECK(Rating > 0 AND RATING <= 10),
	UserId INT NOT NULL REFERENCES Users);

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

CREATE VIEW auth.Users(Id, Login, Password, Email, Author, Moderator, Administrator) AS
  SELECT Id, Login, Password, Email, Author, Moderator, Administrator
  FROM public.Users;

CREATE OR REPLACE FUNCTION 
  auth.RegisterUser(login Users.Login%TYPE, password Users.Password%TYPE, email VARCHAR) returns Users.Id%TYPE 
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

--__Author schema__--
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

--__Create roles__--
DO $$
BEGIN
  CREATE ROLE keter_media_unauthenticated;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_unauthenticated -- it already exists';
END
$$;

REVOKE ALL ON ALL TABLES in SCHEMA unauthenticated FROM keter_media_unauthenticated;
REVOKE ALL ON ALL FUNCTIONS in SCHEMA unauthenticated FROM keter_media_unauthenticated;
REVOKE ALL ON SCHEMA unauthenticated FROM keter_media_unauthenticated;
REVOKE ALL ON DATABASE ketermedia FROM keter_media_unauthenticated;

ALTER ROLE keter_media_unauthenticated WITH
    LOGIN PASSWORD 'keter_media_unauthenticated'
    NOCREATEROLE;
ALTER ROLE keter_media_unauthenticated 
    SET search_path TO 'unauthenticated';



DO $$
BEGIN
  CREATE ROLE keter_media_registered;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_registered -- it already exists';
END
$$;

REVOKE ALL ON ALL TABLES in SCHEMA registered FROM keter_media_registered;
REVOKE ALL ON ALL FUNCTIONS in SCHEMA registered FROM keter_media_registered;
REVOKE ALL ON SCHEMA registered FROM keter_media_registered;
REVOKE ALL ON DATABASE ketermedia FROM keter_media_registered;

ALTER ROLE keter_media_registered WITH
    LOGIN PASSWORD 'keter_media_registered'
    NOCREATEROLE;
ALTER ROLE keter_media_registered 
    SET search_path TO 'registered';



DO $$
BEGIN
    CREATE ROLE keter_media_author;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_author -- it already exists';
END
$$;

REVOKE ALL ON ALL TABLES in SCHEMA author FROM keter_media_author;
REVOKE ALL ON ALL FUNCTIONS in SCHEMA author FROM keter_media_author;
REVOKE ALL ON SCHEMA author FROM keter_media_author;
REVOKE ALL ON DATABASE ketermedia FROM keter_media_author;

ALTER ROLE keter_media_author WITH
    LOGIN PASSWORD 'keter_media_author'
    NOCREATEROLE;
ALTER ROLE keter_media_author 
    SET search_path TO 'author';



DO $$
BEGIN
    CREATE ROLE keter_media_moderator;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_moderator  -- it already exists';
END
$$;

REVOKE ALL ON ALL TABLES in SCHEMA moderator FROM keter_media_moderator;
REVOKE ALL ON ALL FUNCTIONS in SCHEMA moderator FROM keter_media_moderator;
REVOKE ALL ON SCHEMA moderator FROM keter_media_moderator;
REVOKE ALL ON DATABASE ketermedia FROM keter_media_moderator;

ALTER ROLE keter_media_moderator  WITH
    LOGIN PASSWORD 'keter_media_moderator'
    NOCREATEROLE;
ALTER ROLE keter_media_moderator 
    SET search_path TO 'moderator';



DO $$
BEGIN
    CREATE ROLE keter_media_admin;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_admin -- it already exists';
END
$$;

REVOKE ALL ON ALL TABLES in SCHEMA admin FROM keter_media_admin;
REVOKE ALL ON ALL FUNCTIONS in SCHEMA admin FROM keter_media_admin;
REVOKE ALL ON SCHEMA admin FROM keter_media_admin;
REVOKE ALL ON DATABASE ketermedia FROM keter_media_admin;

ALTER ROLE keter_media_admin  WITH
    LOGIN PASSWORD 'keter_media_admin'
    NOCREATEROLE;
ALTER ROLE keter_media_admin 
    SET search_path TO 'admin';
    


DO $$
BEGIN
    CREATE ROLE keter_media_auth;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_auth -- it already exists';
END
$$;

REVOKE ALL ON ALL TABLES in SCHEMA auth FROM keter_media_auth;
REVOKE ALL ON ALL FUNCTIONS in SCHEMA auth FROM keter_media_auth;
REVOKE ALL ON SCHEMA auth FROM keter_media_auth;
REVOKE ALL ON DATABASE ketermedia FROM keter_media_auth;

ALTER ROLE keter_media_auth  WITH
    LOGIN PASSWORD 'keter_media_auth'
    NOCREATEROLE;
ALTER ROLE keter_media_auth 
    SET search_path TO 'auth';

--unauthenticated
GRANT CONNECT ON DATABASE ketermedia TO keter_media_unauthenticated;
GRANT USAGE ON SCHEMA unauthenticated TO keter_media_unauthenticated; 

--user
GRANT CONNECT ON DATABASE ketermedia TO keter_media_registered;
GRANT USAGE ON SCHEMA registered TO keter_media_registered; 

--author
GRANT CONNECT ON DATABASE ketermedia TO keter_media_author;

--moderator
GRANT CONNECT ON DATABASE ketermedia TO keter_media_moderator;

--admin
GRANT CONNECT ON DATABASE ketermedia TO keter_media_admin;

--auth
GRANT CONNECT ON DATABASE ketermedia TO keter_media_auth;
GRANT USAGE ON SCHEMA auth TO keter_media_auth; 
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth to keter_media_auth;


SET SCHEMA 'public'; 
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('First author', decode('8a4fd004c3935d029d5939eb285099ebe4bef324a006a3bfd5420995b70295cd', 'hex'), 'firstauthor@mail.com', true, false, false);

INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
  VALUES('First user', decode('366bbe8741cf9ca2c9b5f3112f3879d646fa65f1e33b9a46cf0d1029be3feaa5', 'hex'), 'firstuser@mail.com', false, false, false);

INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
  VALUES('First moderator', decode('11cc040f692807790efa74107855bd40c4862691d0384baef476b74c6abc1106', 'hex'), 'firstmoderator@mail.com', false, true, false);

INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('First admin', decode('8f28165115617fdd575d1fb94b764ebca67114c91f42ecea4a99868d42d4f3d4', 'hex'), 'firstadmin@mail.com', false, true, false);

