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