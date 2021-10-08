BEGIN; 
 
 
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
	CONSTRAINT email_format CHECK(VALUE ~ '^.+@(.{2,}\.)+.{2,}$');

CREATE DOMAIN HTTPLINK VARCHAR
	CONSTRAINT http_link_format CHECK(VALUE ~ '^https?\/\/(www\.)?([a-z0-9\-]+\.?)+(\/[a-z0-9\-]+)+(\?.*)?$');

CREATE DOMAIN FORMAT VARCHAR 
	CONSTRAINT format CHECK(VALUE ~ '^\..+$');

CREATE DOMAIN ALIAS AS VARCHAR(25)
	CONSTRAINT alias_format CHECK(VALUE ~ '^(\w+\s*)+$');

CREATE TYPE MEDIAKIND as ENUM('Audio', 'Video', 'Image');
CREATE TYPE QUALITY as ENUM('VERY LOW', 'LOW', 'MEDIUM', 'HIGH', 'VERY HIGH');
CREATE TYPE PREVIEWSIZE as ENUM('SMALL', 'MEDIUM', 'LARGE');


--Authentication and user data
CREATE TABLE Users(
  Id BIGSERIAL PRIMARY KEY CONSTRAINT user_primary_key CHECK(Id>0),
  Login VARCHAR(20) NOT NULL CONSTRAINT unique_user_name UNIQUE,
  Password BYTEA NOT NULL,
  Email EMAIL NOT NULL CONSTRAINT unique_email UNIQUE,
  Author BOOLEAN,
  Moderator BOOLEAN,
  Administrator BOOLEAN);

--Mediaproducts and Materials
CREATE TABLE Authors(
	Id BIGSERIAL PRIMARY KEY REFERENCES Users,
	Country VARCHAR(2) NOT NULL REFERENCES Countries ON UPDATE CASCADE ON DELETE RESTRICT);

CREATE TABLE Mediaproducts(
	Id BIGSERIAL PRIMARY KEY CONSTRAINT media_primary_key Check(Id>0),
    Public BOOLEAN DEFAULT TRUE NOT NULL,
	Title VARCHAR(30) NOT NULL,
	AuthorId INT REFERENCES Authors ON DELETE CASCADE,
	Kind MEDIAKIND NOT NULL,
	Date TIMESTAMPTZ NOT NULL,    
	Rating NUMERIC(1000, 999) CHECK(Rating >= 0 AND Rating <= 10),
    Uses BIGINT CHECK(Uses >= 0) NOT NULL DEFAULT 0);

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
	Date TIMESTAMPTZ NOT NULL,
	Relevance BOOLEAN NOT NULL DEFAULT True,
	Substitution INT DEFAULT 1 REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT);

CREATE TABLE Materials(
	Id BIGSERIAL PRIMARY KEY CONSTRAINT material_primary_key Check(Id>0),
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	Format FORMAT NOT NULL,
	Quality QUALITY NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT DEFAULT 1,
    Uses BIGINT CHECK(Uses >= 0) NOT NULL DEFAULT 0);

CREATE TABLE Previews(
	Id BIGSERIAL PRIMARY KEY,
	MediaId INT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	MaterialId INT REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE);

CREATE TABLE MaterialUsage(
	MaterialId BIGINT NOT NULL REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE,
	UserId BIGINT NOT NULL REFERENCES Users ON UPDATE CASCADE ON DELETE CASCADE,
	Date TIMESTAMPTZ NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT,
  PRIMARY KEY(MaterialId, UserId));

CREATE TABLE Reviews(
    Id BIGSERIAL PRIMARY KEY CONSTRAINT review_id CHECK(Id > 0),
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	UserId BIGINT NOT NULL REFERENCES Users,
	Rating SMALLINT NOT NULL CONSTRAINT rating_value CHECK(Rating > 0 AND RATING <= 10),
	Text TEXT CONSTRAINT review_text_not_empty CHECK(Text != ''),
	Date TIMESTAMPTZ NOT NULL,    
    CONSTRAINT one_review_per_user UNIQUE(MediaId, UserId));

CREATE VIEW TextReviews(Id, MediaId, UserId, Rating, Text, Date) AS 
    SELECT Id, MediaId, UserId, Rating, Text, Date FROM Reviews 
    WHERE Text IS NOT NULL;

CREATE TABLE ModerationReasons(
	Id SERIAL PRIMARY KEY,
	Text TEXT NOT NULL);


--TODO: Crate trggier to check if review id references text review
CREATE TABLE Moderation(
    MederatorId BIGINT NOT NULL REFERENCES Users,
	ReviewId BIGINT PRIMARY KEY REFERENCES Reviews ON UPDATE CASCADE ON DELETE CASCADE,
	ReasonId INT NOT NULL REFERENCES ModerationReasons ON UPDATE CASCADE ON DELETE RESTRICT,
    Date TIMESTAMPTZ NOT NULL);

CREATE TABLE AdministrationReasons(
	Id SERIAL PRIMARY KEY,
	Text TEXT NOT NULL);

CREATE TABLE Administration(
    AdminId INT NOT NULL REFERENCES Users,
	MaterialId INT PRIMARY KEY REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE,
	ReasonId INT REFERENCES AdministrationReasons ON UPDATE CASCADE ON DELETE RESTRICT,
    Date TIMESTAMPTZ NOT NULL);


 
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
--__Registered schema__--
DROP SCHEMA IF EXISTS registered CASCADE;
CREATE SCHEMA registered;
SET SCHEMA 'registered';

CREATE OR REPLACE VIEW Users(Id, Name, Author, Moderator, Administrator) AS
  SELECT Id, Login, Author, Moderator, Administrator
    FROM public.Users;

CREATE OR REPLACE FUNCTION PostReview(
  user_id public.Users.Id%TYPE, 
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
  user_id public.Users.Id%TYPE, 
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
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION UseMaterial(
  user_id Users.Id%TYPE, 
  material_id public.Materials.Id%TYPE)
  RETURNS void
  AS $$
    DECLARE
        license_id public.Licenses.Id%TYPE;
		BEGIN
            SELECT LicenseId INTO STRICT license_id
                FROM Materials 
                WHERE Id = material_id;

			INSERT INTO public.MaterialUsage(MaterialId, UserId, Date, LicenseId)
                VALUES (material_id, user_id, current_date, license_id);
		END
  $$ LANGUAGE plpgsql SECURITY DEFINER; 
--__Author schema__--
DROP SCHEMA IF EXISTS author CASCADE;
CREATE SCHEMA author;
SET SCHEMA 'author';

CREATE OR REPLACE FUNCTION AddMaterial(
  user_id public.Users.Id%TYPE,
  media_id public.Mediaproducts.Id%TYPE, 
  license_id public.Licenses.Id%TYPE,
  format public.Materials.Format%TYPE,
  quality public.Materials.Quality%TYPE)
  RETURNS public.Materials.Id%TYPE
  AS $$
    DECLARE
        id public.Materials.Id%TYPE;
        required_user_id public.Users.Id%TYPE;
	BEGIN
        SELECT AuthorId INTO STRICT required_user_id
            FROM public.Mediaproducts
            WHERE Id = media_id;

        IF user_id = required_user_id THEN
            BEGIN
                INSERT INTO public.Materials(MediaId, LicenseId, Format, Quality)
                    VALUES (media_id, license_id, format, quality)
                RETURNING Id INTO STRICT id;

                RETURN Id;
            END;
        ELSE 
            RAISE EXCEPTION 'User_id doesn''t match';
        END IF;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION DeleteMaterial(
  user_id public.Users.Id%TYPE,
  material_id public.Materials.Id%TYPE)
  RETURNS void
  AS $$
    DECLARE
        id public.Materials.Id%TYPE;
        required_user_id public.Users.Id%TYPE;
	BEGIN
        SELECT AuthorId INTO STRICT required_user_id
            FROM public.Mediaproducts
            WHERE Id = media_id;

        IF user_id = required_user_id THEN
            DELETE FROM public.Materials
                WHERE Id = material_id;
        ELSE 
            RAISE EXCEPTION 'User_id doesn''t match';
        END IF;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER; 
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
SET SCHEMA 'test'; 
--__Create roles__--
DO $$
BEGIN
  CREATE ROLE keter_media_unauthenticated NOINHERIT;
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
  RAISE NOTICE 'not creating role keter_media_update -- it already exists';
END
$$;

ALTER ROLE keter_media_update WITH
    LOGIN PASSWORD 'keter_media_update'
    NOCREATEROLE;
ALTER ROLE keter_media_update 
    SET search_path TO 'public';

DO $$
BEGIN
    CREATE ROLE keter_media_store;
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'not creating role keter_media_store -- it already exists';
END
$$;

ALTER ROLE keter_media_store WITH
    LOGIN PASSWORD 'keter_media_store'
    NOCREATEROLE;
ALTER ROLE keter_media_store 
    SET search_path TO 'public';

REVOKE ALL ON ALL TABLES in SCHEMA public FROM keter_media_store;
REVOKE ALL ON SCHEMA auth FROM keter_media_store;
REVOKE ALL ON DATABASE ketermedia FROM keter_media_store; 
GRANT USAGE ON SCHEMA public TO PUBLIC;

--unauthenticated
GRANT CONNECT ON DATABASE ketermedia TO keter_media_unauthenticated;
GRANT USAGE ON SCHEMA unauthenticated TO keter_media_unauthenticated; 
GRANT SELECT ON ALL TABLES IN SCHEMA unauthenticated TO keter_media_unauthenticated;

--user
GRANT CONNECT ON DATABASE ketermedia TO keter_media_registered;

GRANT USAGE ON SCHEMA registered TO keter_media_registered; 
GRANT SELECT ON ALL TABLES IN SCHEMA registered TO keter_media_registered;

GRANT keter_media_unauthenticated TO keter_media_registered;
--author
GRANT CONNECT ON DATABASE ketermedia TO keter_media_author;

GRANT USAGE ON SCHEMA author TO keter_media_author; 
GRANT SELECT ON ALL TABLES IN SCHEMA author TO keter_media_author;

GRANT keter_media_unauthenticated, keter_media_registered TO keter_media_author;

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
  VALUES('First admin', decode('8f28165115617fdd575d1fb94b764ebca67114c91f42ecea4a99868d42d4f3d4', 'hex'), 'firstadmin@mail.com', false, true, false); 
INSERT INTO Authors(Id, Country)
  VALUES(1, 'UA');
INSERT INTO Authors(Id, Country)
  VALUES(2, 'RU');
INSERT INTO Authors(Id, Country)
  VALUES(3, 'BL');
INSERT INTO Authors(Id, Country)
  VALUES(4, 'FR'); 
--Id = 1 AuthorId = 1
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
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(1, '.wav', 'MEDIUM', 1);
--Id = 2 Media_d = 1
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(1, '.mp3', 'LOW', 1);
--Id = 3 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(3, '.bmp', 'HIGH', 2);
--Id = 4 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, '.jpg', 'MEDIUM', 2);
--Id = 5 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, '.giff', 'VERY LOW', 1);
--Id = 6 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, '.ogg', 'MEDIUM', 2);
--Id = 7 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, '.wav', 'HIGH', 2);
--Id = 8 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, '.bmp', 'VERY HIGH', 1);
--Id = 9 Media_d = 6
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(6, '.png', 'MEDIUM', 2);
--Id = 10 Media_d = 2
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(2, '.png', 'MEDIUM', 2);
--Id = 11 Media_d = 4
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(4, '.png', 'MEDIUM', 2);
--Id = 12 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, '.mp4', 'MEDIUM', 1);
 
INSERT INTO Reviews(MediaId, UserId, Text, Rating, Date)
  VALUES(1, 5, 'Not so bad', 6, '2020-12-08 07:07:07');
INSERT INTO Reviews(MediaId, UserId, Text, Rating, Date)
  VALUES(1, 6, 'Nice', 7, '2020-12-08 14:21:09');
INSERT INTO Reviews(MediaId, UserId, Text, Rating, Date)
  VALUES(5, 7, 'First one was better(', 6, '2021-01-02 04:05:06');
COMMIT; 
