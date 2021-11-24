--__Public schema__--
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
SET SCHEMA 'public';

--TYPES AND DOMAINS
CREATE TABLE countries(
	id          VARCHAR(2)  PRIMARY KEY,
	full_name   VARCHAR     NOT NULL);

CREATE UNIQUE INDEX countries_index ON countries(id);

CREATE DOMAIN EMAIL VARCHAR
	CONSTRAINT email_format CHECK(VALUE ~ '^.+@(.{2,}\.)+.{2,}$');

CREATE DOMAIN HTTPLINK VARCHAR
	CONSTRAINT http_link_format CHECK(VALUE ~ '^https?\/\/(www\.)?([a-z0-9\-]+\.?)+(\/[a-z0-9\-]+)+(\?.*)?$');

CREATE DOMAIN ALIAS AS VARCHAR(25)
	CONSTRAINT alias_format CHECK(VALUE ~ '^(\w+\s*)+$');

CREATE TYPE MEDIAKIND as ENUM('audio', 'video', 'image');
CREATE TYPE QUALITY as ENUM('very low', 'low', 'medium', 'high', 'very high');
CREATE TYPE PREVIEWSIZE as ENUM('small', 'medium', 'large');

CREATE TYPE ADMINISTRATION_PERMISSIONS AS ENUM('none', 'moderator', 'admin');

CREATE TYPE FILTER_ORDERING AS ENUM('asc', 'desc');
CREATE TYPE LIMITS AS (
    min BIGINT,
    max BIGINT
);
CREATE TYPE RANGE_FILTER AS (
    ordering    FILTER_ORDERING,
    limits      LIMITS
);

--Authentication and user data
CREATE TABLE users(
  id                            BIGSERIAL                   PRIMARY KEY CONSTRAINT user_primary_key CHECK(id>0),
  login                         VARCHAR(20)                 NOT NULL    CONSTRAINT unique_user_name UNIQUE,
  password                      BYTEA                       NOT NULL,
  email                         EMAIL                       NOT NULL    CONSTRAINT unique_email UNIQUE,
  administration_permissions    ADMINISTRATION_PERMISSIONS  NOT NULL    DEFAULT 'none');

--Mediaproducts and Materials
CREATE TABLE authors(
	id      BIGSERIAL   PRIMARY KEY REFERENCES users,
	country VARCHAR(2)  NOT NULL    REFERENCES countries ON UPDATE CASCADE ON DELETE RESTRICT);

CREATE TABLE mediaproducts(
	id          BIGSERIAL           PRIMARY KEY CONSTRAINT media_primary_key CHECK(id>0),
    public      BOOLEAN             NOT NULL    DEFAULT TRUE,
	title       VARCHAR(30)         NOT NULL,
	author_id   BIGINT              NOT NULL    REFERENCES Authors ON DELETE CASCADE,
	kind        MEDIAKIND           NOT NULL,
	date        TIMESTAMPTZ         NOT NULL,    
    use_count   BIGINT              NOT NULL    CONSTRAINT use_count_bound CHECK(use_count >= 0) DEFAULT 0,
    rating      NUMERIC(1000,999)               CONSTRAINT rating_bounds CHECK(rating > 0 and rating <= 10),

    CONSTRAINT different_media_titles_for_one_author UNIQUE(title, author_id));

CREATE TABLE licenses(
	id              SERIAL      PRIMARY KEY,
	title           CHAR(20)    NOT NULL        UNIQUE,
	text            TEXT        NOT NULL,
	date            TIMESTAMPTZ NOT NULL,
	relevance       BOOLEAN     NOT NULL        DEFAULT True,
	substitution    INT                         DEFAULT 1 REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT);

CREATE TABLE materials(
	id              BIGSERIAL           PRIMARY KEY CONSTRAINT material_primary_key CHECK(id>0),
	media_id        BIGINT              NOT NULL    REFERENCES Mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	format          VARCHAR             NOT NULL,
	quality QUALITY                     NOT NULL,
	license_id      INT                 NOT NULL    REFERENCES Licenses ON UPDATE CASCADE ON DELETE RESTRICT DEFAULT 1,
    use_count       BIGINT              NOT NULL    CHECK(use_count >= 0) DEFAULT 0,
    rating          NUMERIC(1000,999)               CONSTRAINT rating_bounds CHECK(rating > 0 and rating <= 10),
    download_name   VARCHAR             NOT NULL);

CREATE OR REPLACE FUNCTION init_material_download_name() RETURNS TRIGGER
AS $$
    DECLARE
        media_title mediaproducts.title%TYPE;
        author_name users.login%TYPE;
    BEGIN
        SELECT 
            m.title, 
            u.login 
        INTO STRICT 
            media_title, 
            author_name
        FROM users u JOIN mediaproducts m
            ON u.id = m.author_id
        WHERE m.id = NEW.media_id;

        NEW.download_name := CONCAT(author_name, '_', media_title, '[', NEW.id, '].', NEW.format);

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_insert_material
    BEFORE INSERT ON materials
    FOR EACH ROW EXECUTE PROCEDURE init_material_download_name();
    
--TODO: Trigger to check if user is author of material
CREATE TABLE material_usage(
	material_id BIGINT      NOT NULL    REFERENCES materials ON UPDATE CASCADE ON DELETE CASCADE,
	user_id     BIGINT      NOT NULL    REFERENCES users ON UPDATE CASCADE ON DELETE CASCADE,
	date        TIMESTAMPTZ NOT NULL,
	license_id  INT         NOT NULL    REFERENCES licenses ON UPDATE CASCADE ON DELETE RESTRICT,
    rating      SMALLINT                CONSTRAINT rating_bounds CHECK(rating > 0 and rating <= 10),

    PRIMARY KEY(material_id, user_id));

--TODO: Trigger for restricting users from reviewing unused media 
CREATE TABLE reviews(
    id          BIGSERIAL   PRIMARY KEY CONSTRAINT review_id CHECK(id > 0),
	media_id    BIGINT                  REFERENCES mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	user_id     BIGINT      NOT NULL    REFERENCES users,
	text        TEXT        NOT NULL    CONSTRAINT review_text_not_empty CHECK(text != ''),
	date        TIMESTAMPTZ NOT NULL,  

    CONSTRAINT one_review_per_user UNIQUE(media_id, user_id));

CREATE TABLE moderation_reasons(
	id      SERIAL  PRIMARY KEY,
	text    TEXT    NOT NULL);

CREATE TABLE moderation(
    mederator_id    BIGINT      NOT NULL    REFERENCES users,
	review_id       BIGINT      PRIMARY KEY REFERENCES reviews ON UPDATE CASCADE ON DELETE CASCADE,
	reason_id       INT         NOT NULL    REFERENCES moderation_reasons ON UPDATE CASCADE ON DELETE RESTRICT,
    date            TIMESTAMPTZ NOT NULL);

CREATE OR REPLACE FUNCTION check_moderator_permissions() RETURNS TRIGGER
AS $$
    DECLARE
        permissions users.administration_permissions%TYPE;
    BEGIN
        SELECT 
            administration_permissions 
        INTO STRICT 
            permissions 
        FROM users
        WHERE id = NEW.moderator_id;

        IF (permissions < 'moderator') THEN
            RAISE EXCEPTION 
                'Not enough permissions';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_insert_moderation
  BEFORE INSERT ON moderation
  FOR EACH ROW EXECUTE PROCEDURE check_moderator_permissions();

CREATE TABLE administration_reasons(
	id      SERIAL  PRIMARY KEY,
	text    TEXT    NOT NULL);

CREATE TABLE administration(
    admin_id    BIGINT      NOT NULL    REFERENCES users,
	material_id BIGINT      PRIMARY KEY REFERENCES materials ON UPDATE CASCADE ON DELETE CASCADE,
	reason_id   INT         NOT NULL    REFERENCES administration_reasons ON UPDATE CASCADE ON DELETE RESTRICT,
    date        TIMESTAMPTZ NOT NULL);

CREATE OR REPLACE FUNCTION check_admin_permissions() RETURNS TRIGGER
AS $$
    DECLARE
        permissions users.administration_permissions%TYPE;
    BEGIN
        SELECT 
            administration_permissions 
        INTO STRICT 
            permissions 
        FROM users
        WHERE id = NEW.admin_id;

        IF (permissions < 'admin') THEN
            RAISE EXCEPTION 
                'Not enough permissions';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_insert_administration
  BEFORE INSERT ON administration
  FOR EACH ROW EXECUTE PROCEDURE check_admin_permissions();


