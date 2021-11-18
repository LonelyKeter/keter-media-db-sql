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
	AuthorId BIGINT REFERENCES Authors ON DELETE CASCADE,
	Kind MEDIAKIND NOT NULL,
	Date TIMESTAMPTZ NOT NULL,    
    UseCount BIGINT CHECK(UseCount >= 0) NOT NULL DEFAULT 0,
    Rating NUMERIC(1000,999) CONSTRAINT rating_bounds CHECK(Rating > 0 AND Rating <= 10),
    CONSTRAINT different_media_titles_for_one_author UNIQUE(Title, AuthorId));

CREATE TABLE Coauthors(
	CoauthorId BIGINT REFERENCES Authors ON UPDATE CASCADE ON DELETE CASCADE,
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	PRIMARY KEY(CoauthorId, MediaId));

CREATE TABLE Tags(
	Id SERIAL PRIMARY KEY,
	Tag VARCHAR(12) NOT NULL UNIQUE
  --,Popularity NUMERIC(1000, 999) CHECK(VALUE >= 0 AND VALUE <= 10))
  );

CREATE TABLE MediaTags(
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	TagId BIGINT REFERENCES Tags ON UPDATE CASCADE ON DELETE RESTRICT,
	CONSTRAINT one_unique_tag_per_media PRIMARY KEY(MediaId, TagId));

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
	Format VARCHAR NOT NULL,
	Quality QUALITY NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT DEFAULT 1,
    UseCount BIGINT CHECK(UseCount >= 0) NOT NULL DEFAULT 0,
    Rating NUMERIC(1000,999) CONSTRAINT rating_bounds CHECK(Rating > 0 AND Rating <= 10),
    DownloadName VARCHAR NOT NULL);

CREATE OR REPLACE FUNCTION InitMaterialDownloadName() RETURNS TRIGGER
AS $$
    DECLARE
        media_title public.Mediaproducts.Title%TYPE;
        author_name public.Users.Login%TYPE;
    BEGIN
        SELECT M.Title, U.Login INTO STRICT media_title, author_name
            FROM public.Users U JOIN public.Mediaproducts M
            ON U.Id = M.AuthorId
            WHERE M.Id = NEW.MediaId;

        NEW.DownloadName := CONCAT(author_name, '_', media_title, '[', NEW.Id, '].', NEW.Format);

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER OnInsertMaterial
    BEFORE INSERT ON Materials
    FOR EACH ROW EXECUTE PROCEDURE InitMaterialDownloadName();

CREATE TABLE Previews(
	Id BIGSERIAL PRIMARY KEY,
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	MaterialId BIGINT REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE);

--TODO: Trigger to check if user is author of material
CREATE TABLE MaterialUsage(
	MaterialId BIGINT NOT NULL REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE,
	UserId BIGINT NOT NULL REFERENCES Users ON UPDATE CASCADE ON DELETE CASCADE,
	Date TIMESTAMPTZ NOT NULL,
	LicenseId INT REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT,
    Rating SMALLINT CONSTRAINT rating_bounds CHECK(Rating > 0 AND Rating <= 10),
    PRIMARY KEY(MaterialId, UserId));

--TODO: Trigger for restricting users from reviewing unused media 
CREATE TABLE Reviews(
    Id BIGSERIAL PRIMARY KEY CONSTRAINT review_id CHECK(Id > 0),
	MediaId BIGINT REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	UserId BIGINT NOT NULL REFERENCES Users,
	Text TEXT NOT NULL CONSTRAINT review_text_not_empty CHECK(Text != ''),
	Date TIMESTAMPTZ NOT NULL,    
    CONSTRAINT one_review_per_user UNIQUE(MediaId, UserId));

CREATE TABLE ModerationReasons(
	Id SERIAL PRIMARY KEY,
	Text TEXT NOT NULL);

CREATE TABLE Moderation(
    MederatorId BIGINT NOT NULL REFERENCES Users,
	ReviewId BIGINT PRIMARY KEY REFERENCES Reviews ON UPDATE CASCADE ON DELETE CASCADE,
	ReasonId INT NOT NULL REFERENCES ModerationReasons ON UPDATE CASCADE ON DELETE RESTRICT,
    Date TIMESTAMPTZ NOT NULL);

CREATE TABLE AdministrationReasons(
	Id SERIAL PRIMARY KEY,
	Text TEXT NOT NULL);

CREATE TABLE Administration(
    AdminId BIGINT NOT NULL REFERENCES Users,
	MaterialId BIGINT PRIMARY KEY REFERENCES Materials ON UPDATE CASCADE ON DELETE CASCADE,
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
CREATE OR REPLACE VIEW Mediaproducts(Id, Title, Kind, AuthorId, AuthorName, AuthorCountry, Rating, UseCount) AS
  SELECT M.Id, M.Title, M.Kind, U.Id, U.Login, A.Country, (M.Rating::real), M.UseCount
  FROM public.Mediaproducts M 
    INNER JOIN public.Users U 
    ON M.AuthorId = U.Id
    INNER JOIN public.Authors A
    ON A.Id = U.Id
  WHERE M.Public = TRUE;  

--MaterialsPublic
CREATE OR REPLACE VIEW Materials(Id, MediaId, Format, Quality, LicenseName, Rating, UseCount, DownloadName) AS
  SELECT M.Id, M.MediaId, M.Format, M.Quality, L.Title, (M.Rating::real), M.UseCount, DownloadName
    FROM public.Materials M 
        INNER JOIN public.Licenses L 
        ON L.Id = M.LicenseId
    WHERE M.Id NOT IN (SELECT MaterialId FROM public.Administration);


CREATE OR REPLACE VIEW MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) AS
    SELECT MaterialId, UserId, Date, LicenseId, Rating
    FROM public.MaterialUsage; 

--Users
CREATE OR REPLACE VIEW Users(Id, Name, Author, Moderator, Administrator) AS 
    SELECT Id, Login, Author, Moderator, Administrator
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

CREATE OR REPLACE VIEW Reviews(Id, MediaId, UserId, UserName, Text, Date) AS
  SELECT R.Id, R.MediaId, R.UserId, U.Login, R.Text, R.Date
  FROM public.Reviews R 
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

CREATE OR REPLACE FUNCTION PostReview(
  user_id public.Users.Id%TYPE, 
  media_id public.Mediaproducts.Id%TYPE, 
  text TEXT)
  RETURNS void
  AS $$
		BEGIN
			INSERT INTO public.Reviews(MediaId, UserId, Text, Date)
                VALUES (media_id, user_id, text, current_date);
		END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION PostReview(
  user_id public.Users.Id%TYPE, 
  title public.Mediaproducts.Title%TYPE,
  author public.Users.Login%TYPE,
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

	    INSERT INTO public.Reviews(MediaId, UserId, Text, Date)
          VALUES (media_id, user_id, text, current_date);
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION CreateMaterialUsage(
  user_id public.Users.Id%TYPE, 
  material_id public.Materials.Id%TYPE)
  RETURNS void
  AS $$
    DECLARE
        license_id public.Licenses.Id%TYPE;
		BEGIN
            SELECT LicenseId INTO STRICT license_id
                FROM public.Materials 
                WHERE Id = material_id;

			INSERT INTO public.MaterialUsage(MaterialId, UserId, Date, LicenseId)
                VALUES (material_id, user_id, current_date, license_id);
		END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION UpdateMaterialRating(
  material_id public.Materials.Id%TYPE,
  user_id public.Users.Id%TYPE,
  input_rating public.MaterialUsage.Rating%TYPE)
  RETURNS void
  AS $$
	BEGIN
        IF input_rating IS NULL THEN
            RAISE EXCEPTION 'Rating cannot be NULL';
        END IF;

		UPDATE public.MaterialUsage
            SET Rating = input_rating
            WHERE MaterialId = material_id AND UserId = user_id;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;
 
--__Author schema__--
DROP SCHEMA IF EXISTS author CASCADE;
CREATE SCHEMA author;
SET SCHEMA 'author';

CREATE OR REPLACE FUNCTION CreateMedia(
    user_id public.Users.Id%TYPE,
    media_title public.Mediaproducts.Title%TYPE,
    media_kind public.Mediaproducts.Kind%TYPE
)
RETURNS public.Mediaproducts.Id%TYPE 
AS $$
    DECLARE
        created_media_id public.Mediaproducts.Id%TYPE;
    BEGIN
        IF user_id NOT IN(SELECT Id FROM public.Authors) THEN 
            RAISE EXCEPTION 'User creating material shoud be author';
        END IF;

        INSERT INTO public.Mediaproducts(AuthorId, Title, Kind, Date)
            VALUES(user_id, media_title, media_kind, current_date)
            RETURNING Id INTO STRICT created_media_id;

        RETURN created_media_id;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION AddMaterial(
  user_id public.Users.Id%TYPE,
  media_id public.Mediaproducts.Id%TYPE, 
  license_id public.Licenses.Id%TYPE,
  format public.Materials.Format%TYPE,
  quality public.Materials.Quality%TYPE
)
RETURNS public.Materials.Id%TYPE
  AS $$
    DECLARE
        added_material_id public.Materials.Id%TYPE;
        required_user_id public.Users.Id%TYPE;
	BEGIN
        SELECT AuthorId INTO STRICT required_user_id
            FROM public.Mediaproducts
            WHERE Id = media_id;

        IF user_id = required_user_id THEN
            BEGIN
                INSERT INTO public.Materials(MediaId, LicenseId, Format, Quality)
                    VALUES (media_id, license_id, format, quality)
                RETURNING Id INTO STRICT added_material_id;
            END;
        ELSE 
            RAISE EXCEPTION 'User_id doesn''t match';
        END IF;
        
        RETURN added_material_id;
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
INSERT INTO Countries VALUES('SP', 'Spain');--Users
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
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('My first song', 1, 'Audio', '2020-11-11');
--Id = 2 (Preview for id = 1) AuthorId = 1
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date) 
  VALUES(False, 'My first song. Preview', 1, 'Image', '2020-11-11');
--Id = 3  AuthorId = 2
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('My first photo', 2, 'Image', '2020-11-19');
--Id = 4 (Preview for id = 2) AuthorId = 2
INSERT INTO Mediaproducts(Public, Title, AuthorId, Kind, Date) 
  VALUES(False, 'My first photo.Preview', 2, 'Image', '2020-11-19');
--Id = 5 AuthorId = 1
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('My second song', 1, 'Audio', '2020-12-01');
--Id = 6 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('Одесский дворик', 3, 'Image', '2020-12-12');
--Id = 7 AuthorId = 3
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('Настоящая одесса', 3, 'Video', '2020-12-01');
--Id = 8 AuthorId = 4
INSERT INTO Mediaproducts(Title, AuthorId, Kind, Date) 
  VALUES('Very unpopular video', 4, 'Video', '2021-01-02');

 

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
  VALUES(1, 'wav', 'MEDIUM', 1);
--Id = 2 Media_d = 1
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(1, 'mp3', 'LOW', 1);
--Id = 3 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(3, 'bmp', 'HIGH', 2);
--Id = 4 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, 'jpg', 'MEDIUM', 2);
--Id = 5 Media_d = 3
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(3, 'giff', 'VERY LOW', 1);
--Id = 6 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, 'ogg', 'MEDIUM', 2);
--Id = 7 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId)
  VALUES(5, 'wav', 'HIGH', 2);
--Id = 8 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, 'bmp', 'VERY HIGH', 1);
--Id = 9 Media_d = 6
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(6, 'png', 'MEDIUM', 2);
--Id = 10 Media_d = 2
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(2, 'png', 'MEDIUM', 2);
--Id = 11 Media_d = 4
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(4, 'png', 'MEDIUM', 2);
--Id = 12 Media_d = 5
INSERT INTO Materials(MediaId, Format, Quality, LicenseId) 
  VALUES(5, 'mp4', 'MEDIUM', 1); 
INSERT INTO Reviews(MediaId, UserId, Text, Date)
  VALUES(1, 5, 'Not so bad', '2020-12-08 07:07:07');
INSERT INTO Reviews(MediaId, UserId, Text, Date)
  VALUES(1, 6, 'Nice', '2020-12-08 14:21:09');
INSERT INTO Reviews(MediaId, UserId, Text, Date)
  VALUES(5, 7, 'First one was better(', '2021-01-02 04:05:06');
 
--Material usages
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) 
  VALUES(1, 1, '2020-11-15', 1, 6);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId) 
  VALUES(2, 2, '2020-11-17', 1);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId) 
  VALUES(2, 3, '2020-11-19', 1);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId) 
  VALUES(3, 4, '2020-12-02', 2);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) 
  VALUES(5, 1, '2020-12-03', 1, 4);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) 
  VALUES(7, 4, '2020-12-03', 2, 5);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId) 
  VALUES(6, 3, '2020-12-03', 2);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) 
  VALUES(6, 4, '2020-12-04', 2, 7);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) 
  VALUES(4, 3, '2020-12-04', 2, 5);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) 
  VALUES(8, 1, '2020-12-08', 1, 5);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId) 
  VALUES(1, 3, '2020-12-09', 1);
INSERT INTO MaterialUsage(MaterialId, UserId, Date, LicenseId, Rating) 
  VALUES(5, 4, '2020-12-09', 1, 1); 
SELECT update.UpdateRatings();
SELECT update.UpdateUseCount(); 
COMMIT; 
