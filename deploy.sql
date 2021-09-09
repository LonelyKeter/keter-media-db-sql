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

CREATE DOMAIN ALIAS AS VARCHAR(25)
	CHECK(VALUE ~ '^(\w+\s*)+$');

CREATE TYPE MEDIAKIND as ENUM('Audio', 'Video', 'Image');
CREATE TYPE QUALITY as ENUM('VERY LOW', 'LOW', 'MEDIUM', 'HIGH', 'VERY HIGH');
CREATE TYPE PREVIEWSIZE as ENUM('SMALL', 'MEDIUM', 'LARGE');


--Authentication and user data
CREATE TABLE Users(
  Id BIGSERIAL PRIMARY KEY CHECK(Id>0),
  Login VARCHAR(20) UNIQUE NOT NULL,
  Password BYTEA NOT NULL,
  Email EMAIL NOT NULL UNIQUE,
  Author BOOLEAN,
  Moderator BOOLEAN,
  Administrator BOOLEAN);

--Mediaproducts and Materials
CREATE TABLE Authors(
	Id BIGSERIAL PRIMARY KEY REFERENCES Users,
	Country VARCHAR(2) NOT NULL REFERENCES Countries ON UPDATE CASCADE ON DELETE RESTRICT);

CREATE TABLE Mediaproducts(
	Id BIGSERIAL PRIMARY KEY Check(Id>0),
    Public BOOLEAN DEFAULT TRUE NOT NULL,
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
	Id BIGSERIAL PRIMARY KEY,
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
    Public BOOLEAN NOT NULL DEFAULT TRUE,
	Format FORMAT NOT NULL,
	Quality QUALITY NOT NULL,
	Size BIGINT NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT DEFAULT 1,
	DownloadLink HTTPLINK NOT NULL);

CREATE TABLE Previews(
	Id BIGSERIAL PRIMARY KEY,
	MediaId INT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	MaterialId INT REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE);

CREATE TABLE MaterialUsage(
	MaterialId BIGINT NOT NULL REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE,
	UserId BIGINT NOT NULL REFERENCES Users ON UPDATE CASCADE ON DELETE CASCADE,
	Date DATE NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT,
  PRIMARY KEY(MaterialId, UserId));

CREATE TABLE Reviews(
	Id BIGSERIAL PRIMARY KEY,
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	UserId BIGINT NOT NULL REFERENCES Users,
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

--MediaPublic
CREATE OR REPLACE VIEW Mediaproducts(Id, Title, Kind, AuthorId, AuthorName, AuthorCountry, Rating) AS
  SELECT M.Id, M.Title, M.Kind, U.Id, U.Login, A.Country, (M.Rating::real)
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

DROP SCHEMA IF EXISTS test CASCADE;
CREATE SCHEMA test;
SET SCHEMA 'test';--__Create roles__--
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

DO $$
BEGIN
    CREATE ROLE keter_media_test;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_test -- it already exists';
END
$$;

ALTER ROLE keter_media_test WITH
    LOGIN PASSWORD 'keter_media_test'
    NOCREATEROLE;
ALTER ROLE keter_media_auth 
    SET search_path TO 'test';

DO $$
BEGIN
    CREATE ROLE keter_media_update;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_test -- it already exists';
END
$$;

ALTER ROLE keter_media_update WITH
    LOGIN PASSWORD 'keter_media_update'
    NOCREATEROLE;
ALTER ROLE keter_media_update 
    SET search_path TO 'public';--unauthenticated
GRANT CONNECT ON DATABASE ketermedia TO keter_media_unauthenticated;
GRANT USAGE ON SCHEMA unauthenticated TO keter_media_unauthenticated; 
GRANT SELECT ON ALL TABLES IN SCHEMA unauthenticated TO keter_media_unauthenticated;

--user
GRANT CONNECT ON DATABASE ketermedia TO keter_media_registered;
GRANT USAGE ON SCHEMA registered TO keter_media_registered; 

GRANT SELECT ON ALL TABLES IN SCHEMA registered TO keter_media_registered;

--author
GRANT CONNECT ON DATABASE ketermedia TO keter_media_author;

--moderator
GRANT CONNECT ON DATABASE ketermedia TO keter_media_moderator;

--admin
GRANT CONNECT ON DATABASE ketermedia TO keter_media_admin;

--auth
GRANT CONNECT ON DATABASE ketermedia TO keter_media_auth;
GRANT USAGE ON SCHEMA auth TO KETER_MEDIA_AUTH; 
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth to keter_media_auth;

--test
GRANT CONNECT ON DATABASE ketermedia TO keter_media_test;
GRANT USAGE ON SCHEMA test TO keter_media_test; 
GRANT USAGE ON SCHEMA public TO keter_media_test; 
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA test to keter_media_test;

--test
GRANT CONNECT ON DATABASE ketermedia TO keter_media_update;
GRANT USAGE ON SCHEMA public TO keter_media_update; 
--TODO: create update functions and grant permitions
SET SCHEMA 'public'; 
--Countries
INSERT INTO Countries VALUES('UA', 'Ukraine');
INSERT INTO Countries VALUES('RU', 'Russia');
INSERT INTO Countries VALUES('BL', 'Belarus');
INSERT INTO Countries VALUES('IT', 'Italy');
INSERT INTO Countries VALUES('FR', 'France');
INSERT INTO Countries VALUES('GR', 'Germany');
INSERT INTO Countries VALUES('SP', 'Spain');
--Users
--Id = 1
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('First author', decode('8a4fd004c3935d029d5939eb285099ebe4bef324a006a3bfd5420995b70295cd', 'hex'), 'firstauthor@mail.com', true, false, false);
--Id = 2
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('Second author', decode('1782008c43f72ce64ea4a7f05e202b5f0356f69b079d584cf2952a3b8b37fa71', 'hex'), 'secondauthor@mail.com', true, false, false);
--Id = 3
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('Third author', decode('d9f2fa7f824d1e0c4f7acfc95a9ce02ea844015d13548bf21b0ebb8cd4076e43', 'hex'), 'thirdauthor@mail.com', true, false, false);
--Id = 4
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('Fourth author', decode('cc6ca44341a31d8f742d773b7910f55fdfbc236c9819139c92e21e2bfa61f199', 'hex'), 'fourthauthor@mail.com', true, false, false);


--Id = 5
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
  VALUES('First user', decode('366bbe8741cf9ca2c9b5f3112f3879d646fa65f1e33b9a46cf0d1029be3feaa5', 'hex'), 'firstuser@mail.com', false, false, false);
--Id = 6
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator)
  VALUES('First moderator', decode('11cc040f692807790efa74107855bd40c4862691d0384baef476b74c6abc1106', 'hex'), 'firstmoderator@mail.com', false, true, false);
--Id = 7
INSERT INTO Users(Login, Password, Email, Author, Moderator, Administrator) 
  VALUES('First admin', decode('8f28165115617fdd575d1fb94b764ebca67114c91f42ecea4a99868d42d4f3d4', 'hex'), 'firstadmin@mail.com', false, true, false);INSERT INTO Authors(Id, Country)
  VALUES(1, 'UA');
INSERT INTO Authors(Id, Country)
  VALUES(2, 'RU');
INSERT INTO Authors(Id, Country)
  VALUES(3, 'BL');
INSERT INTO Authors(Id, Country)
  VALUES(4, 'FR');--Id = 1 AuthorId = 1
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('My first song', 1, 'Audio', '2020-11-11', 7);
--Id = 2 (Preview for id = 1) AuthorId = 1
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date, Rating) 
  VALUES(False, 'My first song. Preview', 1, 'Image', '2020-11-11', NULL);
--Id = 3  AuthorId = 2
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('My first photo', 2, 'Image', '2020-11-19', 8);
--Id = 4 (Preview for id = 2) AuthorId = 2
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date, Rating) 
  VALUES(False, 'My first photo.Preview', 2, 'Image', '2020-11-19', NULL);
--Id = 5 AuthorId = 1
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('My second song', 1, 'Audio', '2020-12-01', 8);
--Id = 6 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('Одесский дворик', 3, 'Image', '2020-12-12', 9);
--Id = 7 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('Настоящая одесса', 3, 'Video', '2020-12-01', 7);
--Id = 8 AuthorId = 4
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date, Rating) 
  VALUES('Very unpopular video', 4, 'Video', '2021-01-02', 2);
--Licences
--Id = 1
INSERT INTO Licenses(Title, Text, Date, Relevance, Substitution) 
  VALUES(
  'FREE', 
  'You can do whatever you want and however you like', 
  '2020-01-01', 
  TRUE, 
  NULL);
--Id = 2
INSERT INTO Licenses(Title, Text, Date, Relevance, Substitution) 
  VALUES(
  'Creative Commons', 
  'You can do whatever you want and however you like, if you don''t make money', 
  '2020-01-01', 
  TRUE, 
  NULL);
--Materials
--Id = 1 Media_d = 1
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(1, 54347, '.wav', 'MEDIUM', 1, 'https//downloadme.com/dowload?path=somePaTh2');
--Id = 2 Media_d = 1
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(1, 8341, '.mp3', 'LOW', 1, 'https//downloadme.com/dowload?path=somePaTh3');
--Id = 3 Media_d = 3
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(3, 123306, '.bmp', 'HIGH', 2, 'https//downloadme.com/dowload?path=materialPaTh1');
--Id = 4 Media_d = 3
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink)
  VALUES(3, 12345, '.jpg', 'MEDIUM', 2, 'https//downloadme.com/dowload?path=materialPaTh2');
--Id = 5 Media_d = 3
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink)
  VALUES(3, 995, '.giff', 'VERY LOW', 1, 'https//downloadme.com/dowload?path=materialPaTh3');
--Id = 6 Media_d = 5
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink)
  VALUES(5, 2784, '.ogg', 'MEDIUM', 2, 'https//downloadme.com/dowload?path=materialPaTh4');
--Id = 7 Media_d = 5
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink)
  VALUES(5, 45345, '.wav', 'HIGH', 2, 'https//downloadme.com/dowload?path=materialPaTh5');
--Id = 8 Media_d = 5
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(5, 98648, '.bmp', 'VERY HIGH', 1, 'https//downloadme.com/dowload?path=materialPaTh6');
--Id = 9 Media_d = 6
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(6, 5656, '.png', 'MEDIUM', 2, 'https//downloadme.com/dowload?path=materialPaTh7');
--Id = 10 Media_d = 2
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(2, 2456, '.png', 'MEDIUM', 2, 'https//downloadme.com/dowload?path=materialPaTh7');
--Id = 11 Media_d = 4
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(4, 2456, '.png', 'MEDIUM', 2, 'https//downloadme.com/dowload?path=materialPaTh7');
--Id = 12 Media_d = 5
INSERT INTO Materials(MediaId, Size, Format, Quality, LicenseId, DownloadLink) 
  VALUES(5, 25456, '.mp4', 'MEDIUM', 1, 'https//downloadme.com/dowload?path=materialPaTh8');
