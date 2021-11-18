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


