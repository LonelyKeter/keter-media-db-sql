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


