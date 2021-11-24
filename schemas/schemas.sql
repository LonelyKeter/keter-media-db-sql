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


 
DROP SCHEMA IF EXISTS auth CASCADE;
CREATE SCHEMA auth;
SET SCHEMA 'auth';

CREATE VIEW users(
    id, 
    login, 
    password, 
    email, 
    is_author, 
    administration_permissions
) AS
SELECT 
    id, 
    login, 
    password, 
    email, 
    id IN (SELECT id FROM public.authors), 
    administration_permissions 
FROM public.users;

CREATE OR REPLACE FUNCTION 
  register_user(login users.login%TYPE, password users.password%TYPE, email VARCHAR) returns users.id%TYPE 
  AS $$
    DECLARE
		new_id users.id%TYPE;
	BEGIN
		INSERT INTO public.users(login, password, email)
            VALUES(login, password, email)
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
CREATE OR REPLACE VIEW mediaproducts(
    id, 
    title, 
    kind, 
    author_id, 
    author_name, 
    author_country, 
    rating, 
    use_count
) AS
SELECT 
    m.id, 
    m.title,
    m.kind, 
    u.id, 
    u.login, 
    a.country, 
    (m.rating::real), 
    m.use_count
FROM public.mediaproducts m 
INNER JOIN public.users u 
    ON m.author_id = u.id
INNER JOIN public.authors a
    ON a.id = u.id
WHERE m.public = TRUE;  

--MaterialsPublic
CREATE OR REPLACE VIEW materials(
    id, 
    media_id, 
    format, 
    quality, 
    license_name, 
    rating, 
    use_count, 
    download_name
) AS
SELECT 
    m.id, 
    m.media_id, 
    m.format, 
    m.quality, 
    l.title, 
    (m.rating::real), 
    m.use_count, 
    download_name
FROM public.materials m 
INNER JOIN public.licenses l 
    ON l.id = m.license_id
WHERE m.id NOT IN (SELECT material_id FROM public.administration);


CREATE OR REPLACE VIEW material_usage(
    material_id, 
    user_id, 
    date, 
    license_id, 
    rating
) AS
SELECT 
    material_id, 
    user_id, 
    date, 
    license_id,
    rating
FROM public.material_usage; 

--Users
CREATE OR REPLACE VIEW users(
    id, 
    name, 
    is_author, 
    administration_permissions
) AS 
SELECT 
    id, 
    login, 
    id IN (SELECT id FROM public.authors), 
    administration_permissions 
FROM public.users;

--Authors
CREATE OR REPLACE VIEW authors(
    id, 
    name, 
    country
) AS
SELECT 
    u.id, 
    u.login, 
    a.country 
FROM public.users u
INNER JOIN public.authors a
    ON a.id = u.id;

CREATE OR REPLACE VIEW reviews(
    id, 
    media_id, 
    user_id, 
    user_name, 
    text, 
    date
) AS
SELECT 
    r.id, 
    r.media_id, 
    r.user_id, 
    u.login, 
    r.text, 
    r.date
FROM public.reviews r 
INNER JOIN public.users u 
    ON r.user_id = u.id
WHERE r.id NOT IN(SELECT review_id FROM public.moderation);

CREATE OR REPLACE VIEW licenses(
    id, 
    title, 
    text, 
    date
) AS
SELECT 
    id, 
    title, 
    text, 
    date 
FROM public.licenses; 
--__Registered schema__--
DROP SCHEMA IF EXISTS registered CASCADE;
CREATE SCHEMA registered;
SET SCHEMA 'registered';

CREATE OR REPLACE FUNCTION post_review(
  user_id   public.users.Id%TYPE, 
  media_id  public.mediaproducts.Id%TYPE, 
  text      TEXT)
RETURNS void
  AS $$
	BEGIN
		INSERT INTO public.reviews(
            media_id, 
            user_id, 
            text, 
            date)
        VALUES (
            media_id, 
            user_id, 
            text, 
            current_date);
	END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION PostReview(
  user_id   public.users.id%TYPE, 
  title     public.mediaproducts.title%TYPE,
  author    public.users.login%TYPE,
  text TEXT)
  RETURNS void
  AS $$
    DECLARE
      media_id  public.mediaproducts.id%TYPE;
	BEGIN
        SELECT 
            id 
        INTO STRICT 
            media_id
        FROM public.mediaproducts m JOIN public.users u 
            ON m.author_id = u.id 
        WHERE (M.Title = title AND U.Login = author);

	    INSERT INTO public.reviews(
            media_id, 
            user_id, 
            text, 
            date)
        VALUES (
            media_id, 
            user_id, 
            text, 
            current_date);
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION create_material_usage(
  user_id       public.users.id%TYPE, 
  material_id   public.materials.id%TYPE)
  RETURNS void
  AS $$
    DECLARE
    v_license_id public.licenses.id%TYPE;
	BEGIN
        SELECT license_id INTO STRICT v_license_id
            FROM public.materials 
            WHERE id = material_id;

		INSERT INTO public.material_usage(material_id, user_id, date, license_id)
            VALUES (material_id, user_id, current_date, v_license_id);
		END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_material_rating(
  material_id   public.materials.id%TYPE,
  user_id       public.users.id%TYPE,
  input_rating  public.material_usage.rating%TYPE)
  RETURNS void
  AS $$
	BEGIN
        IF input_rating IS NULL THEN
            RAISE EXCEPTION 'Rating cannot be NULL';
        END IF;

		UPDATE public.material_usage
            SET rating = input_rating
            WHERE material_id = material_id AND user_id = user_id;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;
 
--__Author schema__--
DROP SCHEMA IF EXISTS author CASCADE;
CREATE SCHEMA author;
SET SCHEMA 'author';

CREATE OR REPLACE FUNCTION create_media(
    user_id     public.users.id%TYPE,
    media_title public.mediaproducts.title%TYPE,
    media_kind  public.mediaproducts.kind%TYPE
)
RETURNS public.mediaproducts.id%TYPE 
AS $$
    DECLARE
        created_media_id public.mediaproducts.id%TYPE;
    BEGIN
        IF user_id NOT IN(SELECT id FROM public.authors) THEN 
            RAISE EXCEPTION 'User creating material shoud be author';
        END IF;

        INSERT INTO public.mediaproducts(author_id, title, kind, date)
            VALUES(user_id, media_title, media_kind, current_date)
            RETURNING Id 
            INTO STRICT created_media_id;

        RETURN created_media_id;
    END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION add_material(
  user_id       public.users.Id%TYPE,
  media_id      public.mediaproducts.id%TYPE, 
  license_id    public.licenses.id%TYPE,
  format        public.materials.format%TYPE,
  quality       public.materials.quality%TYPE
)
RETURNS public.materials.id%TYPE
  AS $$
    DECLARE
        added_material_id   public.materials.id%TYPE;
        required_user_id    public.users.id%TYPE;
	BEGIN
        SELECT AuthorId INTO STRICT required_user_id
            FROM public.mediaproducts
            WHERE Id = media_id;

        IF user_id = required_user_id THEN
            BEGIN
                INSERT INTO public.materials(media_id, license_id, format, quality)
                    VALUES (media_id, license_id, format, quality)
                RETURNING Id INTO STRICT added_material_id;
            END;
        ELSE 
            RAISE EXCEPTION 'user_id doesn''t match';
        END IF;
        
        RETURN added_material_id;
	END
  $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION delete_material(
  user_id       public.users.id%TYPE,
  material_id   public.materials.id%TYPE)
  RETURNS void
  AS $$
    DECLARE
        id                  public.materials.id%TYPE;
        required_user_id    public.users.id%TYPE;
	BEGIN
        SELECT author_id INTO STRICT required_user_id
            FROM public.mediaproducts
            WHERE id = media_id;

        IF user_id = required_user_id THEN
            DELETE FROM public.materials
                WHERE id = material_id;
        ELSE 
            RAISE EXCEPTION 'user_id doesn''t match';
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

CREATE OR REPLACE FUNCTION update_ratings() RETURNS void
AS $$
BEGIN
    WITH ratings AS (
        SELECT 
            material_id, 
            AVG(rating) AS rating 
        FROM public.material_usage
        GROUP BY material_id
    )
    UPDATE public.materials
        SET rating = r.rating
        FROM ratings r
        WHERE id = r.material_id;

    WITH ratings AS (
        SELECT 
            media_id, 
            AVG(rating) AS rating 
        FROM public.materials
        GROUP BY media_id
    )
    UPDATE public.mediaproducts
        SET rating = r.rating
        FROM ratings r
        WHERE id = r.media_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_use_count() RETURNS void
AS $$
BEGIN
    WITH use_counts AS (
        SELECT 
            material_id, 
            COUNT(*) AS use_count
        FROM public.material_usage
        GROUP BY material_id
    )
    UPDATE public.materials
        SET use_count = u.use_count
        FROM use_counts u
        WHERE id = u.material_id;

    WITH use_counts AS (
        SELECT 
            media_id, 
            SUM(use_count) as use_count
        FROM public.materials
        GROUP BY media_id
    )
    UPDATE public.mediaproducts
        SET use_count = u.use_count
        FROM use_counts u
        WHERE id = u.media_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
DROP SCHEMA IF EXISTS test CASCADE;
CREATE SCHEMA test;
SET SCHEMA 'test';