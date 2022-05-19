BEGIN; 
 
--__Public schema__--
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
SET SCHEMA 'public';

--TYPES AND DOMAINS

CREATE DOMAIN EMAIL VARCHAR
	CONSTRAINT email_format CHECK(VALUE ~ '^.+@(.{2,}\.)+.{2,}$');

CREATE DOMAIN HTTPLINK VARCHAR
	CONSTRAINT http_link_format CHECK(VALUE ~ '^https?\/\/(www\.)?([a-z0-9\-]+\.?)+(\/[a-z0-9\-]+)+(\?.*)?$');

CREATE DOMAIN ALIAS AS VARCHAR(25)
	CONSTRAINT alias_format CHECK(VALUE ~ '^(\w+\s*)+$');

CREATE DOMAIN RATING NUMERIC(1000, 998)
    CONSTRAINT rating_bounds CHECK(VALUE > 0 and VALUE <= 10);

CREATE DOMAIN USER_RATING SMALLINT
    CONSTRAINT rating_bounds CHECK(VALUE > 0 and VALUE <= 10);

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
    email   EMAIL       NOT NULL    UNIQUE,
    rating  RATING);

CREATE TABLE mediaproducts(
	id          BIGSERIAL           PRIMARY KEY CONSTRAINT media_primary_key CHECK(id>0),
    public      BOOLEAN             NOT NULL    DEFAULT TRUE,
	title       VARCHAR(50)         NOT NULL,
	author_id   BIGINT              NOT NULL    REFERENCES Authors ON DELETE CASCADE,
	kind        MEDIAKIND           NOT NULL,
	date        TIMESTAMPTZ         NOT NULL,    
    use_count   BIGINT              NOT NULL    CONSTRAINT use_count_bound CHECK(use_count >= 0) DEFAULT 0,
    rating      RATING,

    CONSTRAINT different_media_titles_for_one_author UNIQUE(title, author_id));

CREATE TABLE licenses(
	id              SERIAL      PRIMARY KEY,
	title           CHAR(40)    NOT NULL        UNIQUE,
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
    use_count       BIGINT              NOT NULL    CONSTRAINT use_count_bound CHECK(use_count >= 0) DEFAULT 0,
    rating          RATING,
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
    rating      USER_RATING,

    PRIMARY KEY(material_id, user_id));

--TODO: Trigger for restricting users from reviewing unused media 
CREATE TABLE reviews(
    id          BIGSERIAL   PRIMARY KEY CONSTRAINT review_id CHECK(id > 0),
	media_id    BIGINT                  REFERENCES mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
	user_id     BIGINT      NOT NULL    REFERENCES users,
	text        TEXT        NOT NULL    CONSTRAINT review_text_not_empty CHECK(text != ''),
	date        TIMESTAMPTZ NOT NULL);

CREATE TABLE moderation_reasons(
	id      SERIAL  PRIMARY KEY,
	text    TEXT    NOT NULL);

CREATE TABLE moderation(
    moderator_id    BIGINT      NOT NULL    REFERENCES users,
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
	media_id    BIGINT      PRIMARY KEY REFERENCES mediaproducts ON UPDATE CASCADE ON DELETE CASCADE,
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
    rating, 
    use_count
) AS
SELECT 
    m.id, 
    m.title,
    m.kind, 
    u.id, 
    u.login, 
    (m.rating::real), 
    m.use_count
FROM public.mediaproducts m 
INNER JOIN public.users u 
    ON m.author_id = u.id
INNER JOIN public.authors a
    ON a.id = u.id
WHERE m.public = TRUE AND m.id NOT IN(SELECT media_id FROM public.administration)
ORDER BY rating DESC NULLS LAST;  

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
    ON l.id = m.license_id;


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
    email,
    rating
) AS
SELECT 
    u.id, 
    u.login,
    a.email,
    (a.rating::real)
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

CREATE OR REPLACE VIEW moderation_reasons(
    id,
    text
) AS 
SELECT
    id,
    text
FROM public.moderation_reasons;

CREATE OR REPLACE VIEW administration_reasons(
    id,
    text
) AS 
SELECT
    id,
    text
FROM public.administration_reasons; 
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

CREATE OR REPLACE FUNCTION post_review(
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
  v_material_id   public.materials.id%TYPE,
  v_user_id       public.users.id%TYPE,
  v_rating        public.material_usage.rating%TYPE)
  RETURNS void
  AS $$
	BEGIN
        IF v_rating IS NULL THEN
            RAISE EXCEPTION 'Rating cannot be NULL';
        END IF;

		UPDATE public.material_usage
            SET rating = v_rating
            WHERE material_id = v_material_id AND user_id = v_user_id;
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
            RETURNING id 
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

CREATE OR REPLACE VIEW moderation(
    moderator_id,
    moderator_name,
    review_id,
    review_text,
    review_date,
    user_id,
    user_name,
    media_id,
    media_title,
    reason_id,
    reason_text,
    date
) AS 
SELECT
    m.moderator_id,
    mod.login,
    rev.id,
    rev.text,
    rev.date,
    rev.user_id,
    u.login,
    mp.id,
    mp.title,
    mr.id,
    mr.text,
    m.date
FROM public.moderation m
INNER JOIN public.moderation_reasons mr
    ON m.reason_id = mr.id
INNER JOIN public.reviews rev
    ON m.review_id = rev.id
INNER JOIN public.mediaproducts mp
    ON rev.media_id = mp.id
INNER JOIN public.users u 
    ON rev.user_id = u.id
INNER JOIN (
    SELECT id, login
    FROM public.users) AS mod
    ON m.moderator_id = mod.id;

CREATE OR REPLACE FUNCTION insert_moderation(
    moderator_id    public.users.id%TYPE, 
    review_id       public.reviews.id%TYPE, 
    reason_id       public.moderation_reasons.id%TYPE)
RETURNS public.reviews.id%TYPE
AS $$
BEGIN
    IF moderator_id NOT IN(
        SELECT id 
        FROM public.users 
        WHERE administration_permissions >= 'moderator'
    ) THEN
        RAISE EXCEPTION 'Not enough permissions for moderating';
    END IF;

    INSERT INTO public.moderation(moderator_id, review_id, reason_id, date)
        VALUES(moderator_id, review_id, reason_id, current_date);
    
    RETURN review_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
 
--__Admin schema__--
DROP SCHEMA IF EXISTS admin CASCADE;
CREATE SCHEMA admin;
SET SCHEMA 'admin';

CREATE OR REPLACE VIEW administration(
    admin_id,
    admin_name,
    media_id,
    media_title,
    author_id,
    author_name,
    reason_id,
    reason_text,
    date
) AS 
SELECT
    a.admin_id,
    adm.login,
    mp.id,
    mp.title,
    u.id,
    u.login,
    ar.id,
    ar.text,
    a.date
FROM public.administration a
INNER JOIN public.administration_reasons ar
    ON a.reason_id = ar.id
INNER JOIN public.mediaproducts mp
    ON a.media_id = mp.id
INNER JOIN public.users u 
    ON mp.author_id = u.id
INNER JOIN (
    SELECT id, login
    FROM public.users) AS adm
    ON a.admin_id = adm.id;

CREATE OR REPLACE FUNCTION insert_moderation(
    admin_id    public.users.id%TYPE, 
    media_id            public.mediaproducts.id%TYPE, 
    reason_id           public.administration_reasons.id%TYPE)
RETURNS public.mediaproducts.id%TYPE
AS $$
BEGIN
    INSERT INTO public.moderation(admin_id, media_id, reason_id, date)
        VALUES(admin_id, media_id, reason_id, current_date);
    
    RETURN media_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;  
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


    WITH ratings AS (
        SELECT 
            author_id, 
            AVG(rating) AS rating 
        FROM public.mediaproducts
        GROUP BY author_id
    )
    UPDATE public.authors
        SET rating = r.rating
        FROM ratings r
        WHERE id = r.author_id;
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
--Users
INSERT INTO users(login, password, email) 
VALUES
    ('First author', decode('8a4fd004c3935d029d5939eb285099ebe4bef324a006a3bfd5420995b70295cd', 'hex'), 'firstauthor@mail.com'), --Id = 1
    ('Second author', decode('1782008c43f72ce64ea4a7f05e202b5f0356f69b079d584cf2952a3b8b37fa71', 'hex'), 'secondauthor@mail.com'), --Id = 2
    ('Third author', decode('d9f2fa7f824d1e0c4f7acfc95a9ce02ea844015d13548bf21b0ebb8cd4076e43', 'hex'), 'thirdauthor@mail.com'), --Id = 3,
    ('Fourth author', decode('cc6ca44341a31d8f742d773b7910f55fdfbc236c9819139c92e21e2bfa61f199', 'hex'), 'fourthauthor@mail.com'), --Id = 4

    ('First user', decode('366bbe8741cf9ca2c9b5f3112f3879d646fa65f1e33b9a46cf0d1029be3feaa5', 'hex'), 'firstuser@mail.com'); --Id = 5

INSERT INTO users(login, password, email, administration_permissions)
VALUES
    ('First moderator', decode('11cc040f692807790efa74107855bd40c4862691d0384baef476b74c6abc1106', 'hex'), 'firstmoderator@mail.com', 'moderator'), --Id = 6
    ('First admin', decode('8f28165115617fdd575d1fb94b764ebca67114c91f42ecea4a99868d42d4f3d4', 'hex'), 'firstadmin@mail.com', 'admin'), --Id = 7
    ('12345', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), '12345@mail.com', 'admin'); --Id = 8


insert into users (login, password, email) values ('Reidar Brisson', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rbrisson0@google.com.au');
insert into users (login, password, email) values ('Griffie Pering', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gpering1@nationalgeographic.com');
insert into users (login, password, email) values ('Dom Faragan', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'dfaragan2@chicagotribune.com');
insert into users (login, password, email) values ('Jannel Poletto', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'jpoletto3@ox.ac.uk');
insert into users (login, password, email) values ('Emerson Wilflinger', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'ewilflinger4@macromedia.com');
insert into users (login, password, email) values ('Miguel Shaddick', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'mshaddick5@hc360.com');
insert into users (login, password, email) values ('Ranee Issitt', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rissitt6@ocn.ne.jp');
insert into users (login, password, email) values ('Rourke Leinster', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rleinster7@netlog.com');
insert into users (login, password, email) values ('Bax Lante', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'blante8@flickr.com');
insert into users (login, password, email) values ('Ruttger Orring', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rorring9@moonfruit.com');
insert into users (login, password, email) values ('Grenville Dobie', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gdobiea@shinystat.com');
insert into users (login, password, email) values ('Anselma Burkwood', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'aburkwoodb@over-blog.com');
insert into users (login, password, email) values ('Rickie Rooper', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rrooperc@chronoengine.com');
insert into users (login, password, email) values ('Huey Cockshut', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'hcockshutd@feedburner.com');
insert into users (login, password, email) values ('Donn O''Curneen', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'docurneene@bravesites.com');
insert into users (login, password, email) values ('Guillaume Nodes', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gnodesf@alexa.com');
insert into users (login, password, email) values ('Huntington Gayne', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'hgayneg@earthlink.net');
insert into users (login, password, email) values ('Bram Reiach', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'breiachh@intel.com');
insert into users (login, password, email) values ('Pail Farrall', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pfarralli@networkadvertising.org');
insert into users (login, password, email) values ('Pall Duckerin', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pduckerinj@vistaprint.com');
insert into users (login, password, email) values ('Arne Cabrales', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'acabralesk@cpanel.net');
insert into users (login, password, email) values ('Sheree Blanket', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sblanketl@tripod.com');
insert into users (login, password, email) values ('Sada Bucky', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sbuckym@php.net');
insert into users (login, password, email) values ('Sal Blakes', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sblakesn@a8.net');
insert into users (login, password, email) values ('Celestia Orys', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'coryso@yahoo.co.jp');
insert into users (login, password, email) values ('Patsy McLaughlan', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pmclaughlanp@soup.io');
insert into users (login, password, email) values ('Rosy Thorbon', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rthorbonq@ihg.com');
insert into users (login, password, email) values ('Fred Rosengart', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'frosengartr@yelp.com');
insert into users (login, password, email) values ('Raynard Chapling', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rchaplings@istockphoto.com');
insert into users (login, password, email) values ('Silvanus Cronkshaw', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'scronkshawt@squidoo.com');
insert into users (login, password, email) values ('Putnam MacRorie', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pmacrorieu@economist.com');
insert into users (login, password, email) values ('Averil Rodda', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'aroddav@google.it');
insert into users (login, password, email) values ('Mag Sargerson', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'msargersonw@rambler.ru');
insert into users (login, password, email) values ('Deeyn Ortet', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'dortetx@howstuffworks.com');
insert into users (login, password, email) values ('Dosi Gallie', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'dgalliey@comcast.net');
insert into users (login, password, email) values ('Patty Pfiffer', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'ppfifferz@go.com');
insert into users (login, password, email) values ('Gard Marshman', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'gmarshman10@upenn.edu');
insert into users (login, password, email) values ('Renate Archambault', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'rarchambault11@goodreads.com');
insert into users (login, password, email) values ('Bette Kobiera', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'bkobiera12@hao123.com');
insert into users (login, password, email) values ('Etheline Blasoni', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'eblasoni13@bravesites.com');
insert into users (login, password, email) values ('Verney Berard', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'vberard14@hao123.com');
insert into users (login, password, email) values ('Stanislaus Gosz', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'sgosz15@drupal.org');
insert into users (login, password, email) values ('Paulie Dowsey', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'pdowsey16@aboutads.info');
insert into users (login, password, email) values ('Cobb Gentil', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'cgentil17@businesswire.com');
insert into users (login, password, email) values ('Mareah Dashper', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'mdashper18@gravatar.com');
insert into users (login, password, email) values ('Liz Van Der Vlies', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'lvan19@theglobeandmail.com');
insert into users (login, password, email) values ('Marris Midgely', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'mmidgely1a@goo.gl');
insert into users (login, password, email) values ('Jackelyn Maguire', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'jmaguire1b@vk.com');
insert into users (login, password, email) values ('Oriana Senter', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'osenter1c@simplemachines.org');
insert into users (login, password, email) values ('Kathlin Hughman', decode('5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', 'hex'), 'khughman1d@google.pl');
 
INSERT INTO authors(id, email)
VALUES
    (1, 'a@mail.com'),
    (2, 'b@mail.com'),
    (3, 'c@mail.com'),
    (4, 'd@mail.com'); 
INSERT INTO mediaproducts(title, author_id, kind, date)
VALUES
  ('consequat purus. Maecenas libero',2,'image','20-07-31'),
  ('blandit at,',3,'image','19-12-14'),
  ('dui. Fusce aliquam,',4,'video','20-08-26'),
  ('nisi. Cum sociis',3,'video','20-04-15'),
  ('aptent',3,'video','20-04-13'),
  ('vel turpis. Aliquam adipiscing',3,'video','19-12-09'),
  ('venenatis vel, faucibus',3,'image','20-08-21'),
  ('varius et, euismod et,',1,'audio','19-12-20'),
  ('diam lorem,',2,'video','20-04-03'),
  ('a, malesuada',3,'image','20-11-09'),
  ('aliquet libero. Integer',1,'image','20-11-29'),
  ('sapien',2,'video','20-03-25'),
  ('erat. Etiam vestibulum',3,'image','20-06-19'),
  ('mollis. Integer tincidunt',2,'audio','20-01-28'),
  ('mus. Aenean eget',3,'audio','20-06-17'),
  ('arcu. Vestibulum',3,'video','20-09-02'),
  ('Curae Donec tincidunt.',3,'image','20-05-20'),
  ('convallis',2,'audio','20-11-24'),
  ('vitae, sodales',1,'image','20-03-22'),
  ('in',1,'video','20-06-26'),
  ('gravida. Aliquam',2,'image','20-01-27'),
  ('non magna.',2,'video','20-10-15'),
  ('Proin eget',3,'image','20-03-16'),
  ('ac mattis',1,'audio','20-08-06'),
  ('gravida molestie arcu. Sed',3,'video','20-07-16');
INSERT INTO mediaproducts(title, author_id, kind, date)
VALUES
  ('consectetuer rhoncus. Nullam',3,'image','19-12-27'),
  ('lacinia.',4,'audio','20-07-15'),
  ('Nunc mauris',2,'video','20-08-20'),
  ('velit eget laoreet posuere,',2,'image','19-11-11'),
  ('quis, tristique ac,',2,'video','19-12-16'),
  ('enim nec tempus',2,'audio','20-01-13'),
  ('lacus, varius et,',4,'image','19-12-28'),
  ('natoque penatibus et',3,'video','20-08-03'),
  ('Integer',3,'video','20-01-11'),
  ('ut',1,'audio','20-01-22'),
  ('Proin velit.',2,'video','20-08-27'),
  ('nec, cursus a, enim.',3,'video','20-11-24'),
  ('amet, consectetuer',1,'image','20-10-05'),
  ('mollis. Integer tincidunt',3,'video','20-11-25'),
  ('laoreet lectus quis',2,'image','20-03-28'),
  ('tincidunt orci',1,'video','20-11-27'),
  ('velit eget',3,'video','19-12-29'),
  ('ligula. Aliquam erat',2,'video','20-02-21'),
  ('elit fermentum',3,'audio','20-06-28'),
  ('velit. Quisque varius. Nam',1,'video','20-07-25'),
  ('ipsum primis',2,'audio','19-12-29'),
  ('in',2,'video','20-03-05'),
  ('eu, eleifend nec, malesuada',2,'audio','20-11-27'),
  ('elementum sem,',2,'audio','20-06-21'),
  ('accumsan convallis, ante',4,'audio','20-01-01');
INSERT INTO mediaproducts(title, author_id, kind, date)
VALUES
  ('nec, euismod',2,'video','20-04-30'),
  ('odio. Phasellus',2,'video','20-01-28'),
  ('lorem fringilla ornare',2,'image','19-11-03'),
  ('Suspendisse sagittis.',1,'video','20-03-28'),
  ('Nullam feugiat',4,'video','19-11-15'),
  ('Morbi',3,'video','20-01-18'),
  ('arcu imperdiet ullamcorper. Duis',3,'image','20-08-23'),
  ('non leo.',3,'audio','20-07-06'),
  ('luctus',2,'image','19-12-22'),
  ('nisi. Cum sociis natoque',4,'video','20-09-29'),
  ('volutpat nunc sit',2,'video','20-11-11'),
  ('ut mi. Duis',2,'audio','20-01-14'),
  ('sodales',4,'video','20-07-24'),
  ('Sed diam',3,'audio','20-04-28'),
  ('Fusce',1,'video','20-08-05'),
  ('lorem',4,'image','20-06-25'),
  ('scelerisque neque',3,'audio','20-03-18'),
  ('laoreet ipsum.',2,'image','20-11-10'),
  ('adipiscing lacus. Ut nec',2,'video','19-11-14'),
  ('mi',2,'video','19-12-28'),
  ('dictum ultricies',2,'audio','20-01-27'),
  ('eu eros. Nam',4,'video','20-07-27'),
  ('rutrum urna, nec',1,'video','20-01-18'),
  ('semper pretium neque.',4,'video','20-09-20'),
  ('eros nec',1,'video','20-01-22');
INSERT INTO mediaproducts(title, author_id, kind, date)
VALUES
  ('Duis mi',3,'audio','20-08-18'),
  ('ut, molestie',3,'image','20-07-17'),
  ('Aenean egestas hendrerit',3,'image','20-07-28'),
  ('Cras eget nisi',2,'image','20-04-02'),
  ('Phasellus libero mauris,',4,'image','20-11-29'),
  ('montes, nascetur ridiculus mus.',3,'audio','20-04-08'),
  ('egestas. Sed pharetra, felis',1,'image','20-03-01'),
  ('dapibus gravida. Aliquam tincidunt,',2,'audio','20-04-14'),
  ('Integer in',3,'audio','19-12-01'),
  ('Proin',1,'video','20-09-14'),
  ('dictum eu, eleifend',2,'audio','20-04-17'),
  ('nunc risus',2,'video','20-06-22'),
  ('purus.',1,'audio','20-02-02'),
  ('diam. Proin dolor.',2,'video','20-06-25'),
  ('mi',1,'video','20-02-25'),
  ('ipsum leo elementum',4,'audio','20-03-04'),
  ('sem, consequat nec, mollis',1,'video','19-11-27'),
  ('auctor odio a',3,'video','20-10-16'),
  ('dictum. Phasellus',1,'image','19-12-02'),
  ('semper et, lacinia',2,'image','20-05-12'),
  ('mattis ornare, lectus',2,'image','20-11-30'),
  ('fermentum vel,',2,'audio','20-05-26'),
  ('egestas.',4,'video','20-02-02'),
  ('a sollicitudin',1,'image','20-07-27'),
  ('Pellentesque',2,'audio','19-12-30');


 

--Licences
INSERT INTO licenses(title, text, date, relevance, substitution) 
VALUES
  ('FREE', 
  'You can do whatever you want and however you like', 
  '2020-01-01', 
  TRUE, 
  NULL), --Id = 1
  ('Creative Commons', 
  'You can do whatever you want and however you like, if you don''t make money', 
  '2020-01-01', 
  TRUE, 
  NULL), --Id = 2
  ('Unlimitted paid access', 
  'You can do whatever you want and however you like, if you paid author', 
  '2020-11-01', 
  TRUE, 
  NULL); --Id = 3 
--Materials
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (16,'ogg','low',3),
  (13,'png','high',1),
  (74,'avi','medium',1),
  (4,'wav.','very high',3),
  (71,'ogg','low',3),
  (67,'mp4','very high',3),
  (27,'ogg','high',1),
  (55,'jpg','very high',3),
  (97,'jpg','medium',2),
  (6,'png','low',1),
  (36,'jpg','medium',1),
  (47,'mp4','very high',1),
  (17,'avi','low',3),
  (44,'ogg','medium',1),
  (43,'mp4','high',1),
  (45,'bmp','low',3),
  (26,'jpg','medium',1),
  (80,'jpg','low',1),
  (80,'giff','high',3),
  (57,'bmp','medium',1),
  (28,'bmp','high',3),
  (22,'png','very low',1),
  (82,'mp4','low',3),
  (59,'jpg','medium',2),
  (76,'mp4','medium',2),
  (9,'jpg','low',1),
  (75,'png','very low',2),
  (31,'mp3','very high',1),
  (28,'mp3','medium',1),
  (68,'ogg','very high',2),
  (76,'png','high',1),
  (90,'png','very low',2),
  (47,'mp3','very low',1),
  (24,'ogg','very low',3),
  (89,'png','high',1),
  (52,'jpg','very low',1),
  (34,'bmp','high',2),
  (53,'giff','high',1),
  (6,'avi','medium',2),
  (18,'bmp','medium',1),
  (68,'bmp','low',1),
  (33,'ogg','very low',2),
  (64,'wav.','medium',3),
  (57,'mp3','medium',2),
  (99,'mp4','very high',2),
  (42,'bmp','medium',1),
  (46,'mp3','very low',2),
  (10,'wav.','high',2),
  (1,'mp4','medium',2),
  (27,'jpeg','very low',2);
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (91,'wav.','high',1),
  (86,'jpeg','very low',2),
  (11,'png','medium',1),
  (51,'jpeg','very low',1),
  (39,'avi','low',1),
  (62,'bmp','very high',2),
  (66,'bmp','low',2),
  (30,'avi','very low',2),
  (68,'jpeg','high',2),
  (45,'mp3','very low',1),
  (83,'mp4','medium',3),
  (61,'giff','medium',2),
  (27,'jpeg','low',3),
  (20,'mp3','very low',3),
  (36,'jpg','very high',2),
  (38,'giff','very low',1),
  (46,'bmp','very low',2),
  (20,'png','high',3),
  (33,'bmp','high',2),
  (86,'jpg','very high',2),
  (83,'ogg','high',1),
  (33,'ogg','very high',3),
  (48,'mp3','low',2),
  (25,'avi','low',1),
  (68,'mp4','very low',3),
  (15,'mp4','low',3),
  (93,'jpg','very low',1),
  (7,'ogg','very high',2),
  (62,'giff','high',3),
  (71,'mp3','very low',3),
  (44,'wav.','high',2),
  (67,'png','low',2),
  (8,'wav.','medium',1),
  (23,'giff','high',3),
  (92,'wav.','medium',2),
  (12,'mp3','very low',2),
  (3,'wav.','very low',3),
  (73,'mp3','very low',1),
  (88,'ogg','very low',1),
  (17,'png','medium',1),
  (15,'wav.','low',3),
  (29,'ogg','very low',2),
  (5,'mp3','low',2),
  (59,'bmp','very low',2),
  (43,'jpg','high',1),
  (15,'bmp','high',1),
  (52,'jpg','very high',2),
  (72,'ogg','medium',2),
  (4,'wav.','low',2),
  (47,'avi','low',1);
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (21,'png','very low',2),
  (61,'wav.','medium',1),
  (85,'ogg','very low',1),
  (8,'mp3','low',1),
  (66,'jpeg','very high',3),
  (56,'giff','very high',1),
  (2,'giff','high',2),
  (52,'jpg','low',2),
  (42,'png','low',2),
  (63,'jpg','very low',2),
  (67,'mp3','very high',2),
  (39,'jpg','low',1),
  (99,'giff','low',2),
  (90,'wav.','medium',1),
  (24,'avi','medium',1),
  (56,'giff','low',2),
  (39,'mp3','very high',2),
  (4,'ogg','low',2),
  (28,'jpeg','very high',2),
  (8,'bmp','high',1),
  (9,'png','very low',1),
  (18,'bmp','medium',3),
  (71,'giff','medium',2),
  (56,'mp4','high',2),
  (15,'ogg','very high',2),
  (64,'png','medium',3),
  (71,'wav.','high',2),
  (87,'jpeg','very low',2),
  (83,'mp3','very low',2),
  (80,'mp3','medium',3),
  (50,'mp3','medium',2),
  (69,'mp4','low',3),
  (59,'wav.','high',3),
  (82,'avi','low',1),
  (75,'jpeg','medium',2),
  (34,'ogg','high',3),
  (79,'jpg','very high',1),
  (70,'mp3','medium',1),
  (21,'jpeg','medium',3),
  (75,'jpeg','very low',3),
  (70,'mp4','high',3),
  (6,'giff','high',2),
  (37,'bmp','low',2),
  (25,'jpeg','very high',2),
  (67,'mp4','high',2),
  (36,'giff','medium',2),
  (30,'giff','low',1),
  (54,'mp4','medium',3),
  (63,'bmp','low',3),
  (5,'avi','very high',2);
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (85,'ogg','very low',2),
  (24,'wav.','very high',2),
  (42,'giff','medium',1),
  (13,'mp3','very low',2),
  (26,'giff','very low',2),
  (97,'bmp','low',1),
  (44,'giff','very high',1),
  (75,'ogg','high',1),
  (25,'mp4','medium',2),
  (76,'avi','high',3),
  (5,'avi','very low',2),
  (90,'giff','medium',2),
  (92,'mp4','low',2),
  (41,'bmp','medium',3),
  (24,'jpeg','medium',1),
  (99,'png','very low',1),
  (52,'ogg','very low',3),
  (95,'jpg','very low',3),
  (55,'mp4','high',1),
  (24,'avi','very high',3),
  (73,'jpeg','very low',2),
  (29,'png','low',1),
  (73,'mp3','very low',2),
  (71,'jpeg','high',3),
  (77,'jpeg','very low',1),
  (32,'jpg','very low',1),
  (23,'mp3','high',2),
  (38,'png','medium',1),
  (82,'png','very low',1),
  (7,'avi','very low',3),
  (4,'jpg','low',2),
  (41,'giff','very high',2),
  (25,'jpg','medium',2),
  (52,'bmp','high',2),
  (59,'mp4','low',2),
  (23,'mp3','very low',2),
  (69,'mp4','medium',3),
  (32,'bmp','low',3),
  (12,'jpg','very high',2),
  (70,'bmp','high',3),
  (41,'mp4','low',3),
  (53,'mp3','very high',1),
  (54,'jpeg','high',2),
  (53,'ogg','high',2),
  (30,'giff','high',2),
  (32,'png','medium',3),
  (4,'wav.','very low',1),
  (13,'avi','medium',2),
  (32,'jpg','low',2),
  (90,'mp4','very low',1);
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (21,'wav.','very low',2),
  (16,'avi','low',1),
  (92,'mp4','high',1),
  (12,'jpeg','very high',3),
  (77,'mp3','very low',1),
  (37,'mp4','very low',2),
  (48,'avi','high',3),
  (49,'ogg','medium',3),
  (90,'ogg','very low',3),
  (10,'bmp','very high',1),
  (19,'avi','very high',1),
  (46,'avi','very low',3),
  (40,'giff','very high',2),
  (27,'jpg','very low',2),
  (36,'mp3','low',2),
  (75,'jpg','very low',3),
  (63,'mp4','very high',2),
  (5,'jpeg','medium',2),
  (57,'jpg','very high',2),
  (76,'avi','medium',3),
  (14,'jpeg','high',1),
  (36,'ogg','very high',3),
  (2,'png','high',1),
  (23,'avi','high',1),
  (32,'avi','medium',1),
  (53,'jpg','very low',1),
  (90,'bmp','medium',2),
  (38,'giff','very high',1),
  (62,'avi','low',1),
  (4,'png','low',2),
  (99,'ogg','high',3),
  (100,'jpg','low',2),
  (43,'png','very low',2),
  (93,'jpeg','very high',2),
  (33,'wav.','medium',1),
  (50,'mp3','high',2),
  (35,'png','very low',2),
  (25,'avi','low',1),
  (56,'giff','low',1),
  (96,'mp3','medium',1),
  (43,'jpg','very low',2),
  (96,'giff','high',3),
  (77,'jpg','very low',3),
  (4,'jpeg','high',2),
  (79,'bmp','medium',3),
  (45,'wav.','medium',1),
  (71,'png','very high',2),
  (56,'giff','medium',1),
  (64,'ogg','medium',2),
  (12,'giff','high',1);
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (26,'ogg','low',3),
  (87,'mp4','very low',2),
  (47,'png','very low',2),
  (94,'jpeg','very low',1),
  (55,'jpeg','high',1),
  (2,'jpeg','medium',1),
  (58,'mp3','high',3),
  (77,'jpeg','high',3),
  (4,'avi','low',2),
  (50,'mp3','high',2),
  (5,'bmp','low',2),
  (91,'avi','very high',2),
  (99,'jpeg','very high',2),
  (37,'ogg','high',2),
  (12,'wav.','very low',3),
  (58,'avi','high',3),
  (81,'avi','very low',1),
  (38,'png','medium',3),
  (82,'ogg','medium',2),
  (8,'bmp','very high',2),
  (61,'mp4','medium',2),
  (6,'bmp','low',1),
  (44,'jpg','medium',1),
  (34,'mp3','high',2),
  (64,'giff','medium',3),
  (90,'ogg','medium',2),
  (18,'bmp','high',2),
  (22,'mp4','high',2),
  (45,'giff','very high',2),
  (29,'giff','medium',2),
  (44,'png','very low',1),
  (24,'giff','very high',2),
  (52,'bmp','low',3),
  (100,'mp3','very high',2),
  (78,'mp3','very high',2),
  (43,'mp4','very high',1),
  (14,'mp3','medium',1),
  (70,'giff','very high',2),
  (92,'png','medium',1),
  (94,'wav.','high',2),
  (61,'jpg','medium',3),
  (14,'mp4','very low',2),
  (85,'png','low',2),
  (34,'wav.','medium',2),
  (37,'jpg','very high',2),
  (74,'wav.','low',2),
  (40,'wav.','very high',3),
  (6,'ogg','high',3),
  (22,'mp3','medium',2),
  (96,'mp3','medium',2);
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (33,'wav.','very low',2),
  (50,'mp3','very high',2),
  (70,'avi','low',1),
  (23,'avi','very low',2),
  (98,'jpeg','very high',2),
  (99,'ogg','very high',1),
  (14,'giff','very high',2),
  (4,'wav.','low',1),
  (95,'wav.','very high',2),
  (20,'mp3','very low',2),
  (80,'jpg','high',2),
  (84,'mp3','low',2),
  (80,'wav.','medium',3),
  (77,'mp4','very high',3),
  (17,'ogg','very high',3),
  (56,'avi','low',2),
  (56,'jpg','high',2),
  (81,'ogg','very high',2),
  (28,'bmp','high',3),
  (60,'bmp','low',1),
  (19,'mp4','high',3),
  (31,'mp3','medium',2),
  (86,'jpg','low',3),
  (38,'jpeg','very high',2),
  (71,'mp4','very high',2),
  (72,'mp4','medium',1),
  (93,'wav.','medium',2),
  (62,'bmp','medium',1),
  (73,'avi','low',2),
  (38,'ogg','very low',3),
  (50,'giff','very low',3),
  (14,'wav.','high',3),
  (19,'jpeg','high',2),
  (16,'wav.','very high',2),
  (77,'ogg','high',3),
  (84,'jpeg','very high',3),
  (89,'mp4','high',2),
  (72,'mp3','very high',3),
  (5,'mp4','very high',1),
  (35,'mp3','very low',2),
  (51,'jpg','low',2),
  (1,'wav.','high',1),
  (98,'ogg','very low',2),
  (4,'giff','high',2),
  (35,'mp3','very high',3),
  (38,'ogg','medium',3),
  (62,'giff','high',2),
  (60,'mp3','medium',3),
  (85,'jpeg','very high',2),
  (67,'mp4','very high',2);
INSERT INTO materials (media_id,format,quality,license_id)
VALUES
  (74,'png','very high',1),
  (13,'avi','medium',2),
  (72,'png','very high',2),
  (42,'giff','low',2),
  (17,'jpeg','low',3),
  (64,'jpg','low',1),
  (68,'bmp','very low',2),
  (31,'wav.','very low',2),
  (60,'ogg','high',2),
  (11,'jpeg','medium',3),
  (85,'jpg','low',1),
  (63,'jpg','low',2),
  (19,'mp3','medium',2),
  (15,'mp3','medium',2),
  (87,'jpeg','very low',3),
  (76,'jpg','very high',2),
  (39,'jpeg','very high',3),
  (54,'giff','medium',1),
  (55,'avi','very low',2),
  (45,'jpg','very high',1),
  (20,'png','high',2),
  (19,'avi','very low',2),
  (21,'bmp','low',2),
  (67,'jpg','very high',2),
  (39,'jpeg','very low',1),
  (85,'bmp','medium',2),
  (55,'jpeg','medium',2),
  (33,'giff','medium',2),
  (43,'giff','very low',2),
  (47,'jpeg','medium',1),
  (82,'giff','very low',2),
  (38,'giff','medium',1),
  (81,'wav.','very low',3),
  (100,'jpeg','medium',2),
  (46,'ogg','very high',2),
  (52,'mp3','medium',2),
  (44,'jpeg','very low',3),
  (52,'giff','low',2),
  (78,'png','very high',2),
  (44,'jpg','high',1),
  (100,'giff','medium',3),
  (96,'jpg','very low',3),
  (6,'ogg','very high',2),
  (9,'wav.','very high',2),
  (30,'avi','very high',2),
  (94,'bmp','very low',2),
  (66,'png','high',1),
  (32,'mp3','very low',1),
  (43,'mp4','medium',2),
  (51,'mp4','very high',2);
 
INSERT INTO reviews(media_id, user_id, text, date)
  VALUES(1, 5, 'Not so bad', '2020-12-08 07:07:07');
INSERT INTO reviews(media_id, user_id, text, date)
  VALUES(1, 6, 'Nice', '2020-12-08 14:21:09');
INSERT INTO reviews(media_id, user_id, text, date)
  VALUES(5, 7, 'First one was better(', '2021-01-02 04:05:06');

INSERT INTO reviews (media_id,user_id,text,date)
VALUES
  (86,26,'Lorem ipsum dolor','20-02-06'),
  (48,38,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-10-14'),
  (30,17,'Lorem ipsum','20-07-20'),
  (50,31,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-05-25'),
  (90,50,'Lorem ipsum dolor sit','20-09-12'),
  (94,52,'Lorem ipsum dolor sit amet, consectetuer','20-03-06'),
  (78,48,'Lorem','20-03-30'),
  (67,46,'Lorem','20-01-25'),
  (42,20,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-11-16'),
  (9,22,'Lorem ipsum','20-09-25'),
  (30,13,'Lorem ipsum dolor sit amet, consectetuer adipiscing','21-02-25'),
  (76,40,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-10-15'),
  (75,13,'Lorem ipsum','20-12-14'),
  (17,39,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-04-07'),
  (53,18,'Lorem ipsum','20-07-13'),
  (7,48,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-02-26'),
  (55,52,'Lorem ipsum dolor sit amet, consectetuer','20-01-11'),
  (48,37,'Lorem ipsum dolor sit','20-04-03'),
  (81,21,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-09-25'),
  (93,19,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-05-19'),
  (76,50,'Lorem ipsum dolor','20-06-15'),
  (97,19,'Lorem ipsum dolor sit amet,','20-06-10'),
  (27,19,'Lorem ipsum dolor','20-03-22'),
  (23,50,'Lorem ipsum','20-01-27'),
  (9,28,'Lorem ipsum','20-04-13'),
  (85,15,'Lorem ipsum dolor','20-02-06'),
  (8,38,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-01-08'),
  (87,21,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-01-16'),
  (54,16,'Lorem ipsum dolor sit amet, consectetuer','20-10-22'),
  (52,43,'Lorem','21-01-15'),
  (15,49,'Lorem ipsum dolor sit','20-09-09'),
  (58,37,'Lorem ipsum dolor','20-06-26'),
  (32,23,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-03-23'),
  (100,30,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-02-21'),
  (95,36,'Lorem ipsum dolor sit amet, consectetuer adipiscing','21-01-13'),
  (78,57,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-04-05'),
  (98,45,'Lorem ipsum dolor sit','20-03-09'),
  (50,53,'Lorem ipsum dolor','20-06-06'),
  (86,57,'Lorem ipsum dolor','21-01-10'),
  (45,41,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-08-22'),
  (13,53,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-08-05'),
  (2,40,'Lorem ipsum dolor','20-06-12'),
  (72,37,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-06-18'),
  (64,19,'Lorem ipsum dolor sit amet, consectetuer','20-02-08'),
  (80,42,'Lorem ipsum dolor sit amet, consectetuer','20-01-11'),
  (54,41,'Lorem ipsum dolor sit amet, consectetuer','21-02-25'),
  (79,50,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-09-08'),
  (54,40,'Lorem ipsum dolor sit','21-01-29'),
  (10,56,'Lorem ipsum','20-05-10'),
  (31,10,'Lorem ipsum dolor sit','20-07-13');
INSERT INTO reviews (media_id,user_id,text,date)
VALUES
  (16,38,'Lorem','20-05-02'),
  (83,26,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-03-07'),
  (82,10,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-01-01'),
  (32,20,'Lorem ipsum dolor sit amet, consectetuer','20-01-02'),
  (51,22,'Lorem ipsum dolor sit amet, consectetuer','20-09-11'),
  (66,18,'Lorem ipsum dolor','20-03-28'),
  (19,30,'Lorem ipsum','21-02-23'),
  (52,46,'Lorem','20-06-25'),
  (86,51,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-07-16'),
  (42,40,'Lorem ipsum dolor','21-02-27'),
  (90,43,'Lorem ipsum','20-07-06'),
  (83,41,'Lorem ipsum','20-06-18'),
  (76,54,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-07-11'),
  (83,50,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-04-04'),
  (15,25,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-10-29'),
  (77,57,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-07-10'),
  (22,35,'Lorem ipsum dolor sit amet,','20-08-28'),
  (92,20,'Lorem ipsum dolor','20-06-05'),
  (58,18,'Lorem ipsum dolor sit','20-04-06'),
  (78,27,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-02-13'),
  (90,15,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-06-24'),
  (22,24,'Lorem ipsum dolor sit','21-03-30'),
  (74,30,'Lorem ipsum dolor sit amet,','20-11-05'),
  (45,33,'Lorem ipsum dolor sit','20-05-07'),
  (48,57,'Lorem ipsum dolor','20-03-31'),
  (87,25,'Lorem ipsum dolor sit amet,','20-10-05'),
  (75,41,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-05-07'),
  (26,44,'Lorem ipsum dolor sit amet,','20-10-11'),
  (65,44,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-04-26'),
  (87,29,'Lorem ipsum dolor sit amet,','21-02-20'),
  (14,50,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-08-26'),
  (35,42,'Lorem ipsum','20-12-05'),
  (72,46,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-10-07'),
  (6,47,'Lorem ipsum dolor','20-05-27'),
  (18,36,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-02-27'),
  (98,28,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-01-16'),
  (63,58,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-02-20'),
  (60,13,'Lorem ipsum dolor sit amet,','20-04-08'),
  (70,20,'Lorem ipsum dolor','20-05-16'),
  (45,17,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-03-01'),
  (21,49,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-02-17'),
  (72,36,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-09-11'),
  (41,49,'Lorem ipsum dolor sit amet,','20-07-24'),
  (63,35,'Lorem ipsum dolor sit','20-06-04'),
  (30,31,'Lorem ipsum dolor','21-02-24'),
  (80,39,'Lorem','21-01-08'),
  (88,12,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-12-13'),
  (87,42,'Lorem ipsum dolor sit amet, consectetuer','20-09-30'),
  (72,39,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-04-24'),
  (98,26,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-08-07');
INSERT INTO reviews (media_id,user_id,text,date)
VALUES
  (93,27,'Lorem','20-07-26'),
  (71,16,'Lorem ipsum dolor','20-08-20'),
  (8,20,'Lorem ipsum dolor','20-05-03'),
  (66,26,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-11-13'),
  (14,26,'Lorem ipsum','20-06-22'),
  (18,19,'Lorem ipsum dolor','21-02-12'),
  (35,48,'Lorem ipsum dolor','20-06-22'),
  (40,53,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-02-27'),
  (83,48,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-05-05'),
  (82,53,'Lorem ipsum dolor sit amet, consectetuer adipiscing','21-03-26'),
  (43,44,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','21-01-24'),
  (60,41,'Lorem ipsum dolor','20-04-11'),
  (48,14,'Lorem ipsum','20-02-17'),
  (6,31,'Lorem ipsum','21-01-12'),
  (15,35,'Lorem ipsum','20-07-22'),
  (10,26,'Lorem ipsum dolor','20-05-10'),
  (79,23,'Lorem ipsum','20-02-25'),
  (11,50,'Lorem ipsum','20-01-02'),
  (67,13,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-01-22'),
  (73,27,'Lorem ipsum dolor sit amet,','20-04-17'),
  (78,36,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-05-17'),
  (4,36,'Lorem ipsum dolor sit amet,','20-12-30'),
  (100,22,'Lorem ipsum dolor sit amet,','20-08-01'),
  (38,17,'Lorem ipsum dolor sit','21-01-15'),
  (82,41,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-02-10'),
  (88,20,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-11-22'),
  (41,17,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-02-19'),
  (95,31,'Lorem ipsum dolor sit','20-02-17'),
  (67,41,'Lorem ipsum dolor sit','20-06-04'),
  (3,11,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-08-04'),
  (79,12,'Lorem ipsum','20-07-16'),
  (24,49,'Lorem ipsum','20-02-26'),
  (4,13,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-05-23'),
  (26,35,'Lorem ipsum dolor sit amet, consectetuer','20-07-30'),
  (42,33,'Lorem ipsum dolor sit amet, consectetuer','20-08-23'),
  (34,54,'Lorem ipsum dolor sit amet,','20-09-14'),
  (59,21,'Lorem ipsum dolor sit','20-03-03'),
  (21,16,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-12-26'),
  (28,11,'Lorem ipsum dolor sit amet, consectetuer','20-04-01'),
  (2,48,'Lorem ipsum dolor sit amet, consectetuer','20-01-18'),
  (12,55,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-09-23'),
  (81,52,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-01-19'),
  (97,40,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-02-02'),
  (21,19,'Lorem ipsum dolor sit','20-09-18'),
  (100,32,'Lorem ipsum dolor sit','20-01-17'),
  (12,36,'Lorem ipsum dolor','20-09-14'),
  (77,17,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-01-21'),
  (82,29,'Lorem ipsum dolor sit amet, consectetuer','20-06-29'),
  (68,51,'Lorem ipsum dolor','21-03-29'),
  (80,43,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-06-12');
INSERT INTO reviews (media_id,user_id,text,date)
VALUES
  (89,39,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-09-30'),
  (59,21,'Lorem ipsum dolor sit','20-10-28'),
  (48,55,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-03-25'),
  (58,11,'Lorem ipsum dolor sit amet,','20-10-12'),
  (84,27,'Lorem ipsum dolor','20-05-17'),
  (56,55,'Lorem ipsum dolor sit','20-06-14'),
  (7,36,'Lorem ipsum dolor','21-02-18'),
  (15,27,'Lorem ipsum dolor sit','21-01-22'),
  (49,53,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-02-28'),
  (48,11,'Lorem ipsum dolor sit amet, consectetuer','20-03-23'),
  (75,51,'Lorem ipsum','20-02-03'),
  (67,48,'Lorem ipsum dolor sit','20-09-25'),
  (43,40,'Lorem ipsum','20-07-17'),
  (55,57,'Lorem ipsum dolor sit amet,','21-01-01'),
  (33,20,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-05-21'),
  (5,18,'Lorem ipsum','21-03-08'),
  (95,40,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-05-24'),
  (67,35,'Lorem','20-05-28'),
  (6,27,'Lorem ipsum dolor','21-01-22'),
  (43,32,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-03-21'),
  (52,40,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-03-04'),
  (99,17,'Lorem ipsum dolor sit','21-03-15'),
  (7,35,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-10-16'),
  (12,47,'Lorem ipsum dolor sit amet,','20-06-21'),
  (66,52,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-10-04'),
  (78,53,'Lorem ipsum dolor sit','21-02-05'),
  (49,40,'Lorem ipsum dolor','20-06-07'),
  (77,19,'Lorem ipsum dolor sit amet, consectetuer adipiscing','21-03-26'),
  (74,40,'Lorem ipsum dolor','20-10-11'),
  (19,28,'Lorem ipsum dolor','20-04-01'),
  (33,45,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-03-26'),
  (85,37,'Lorem ipsum dolor sit amet, consectetuer','21-01-13'),
  (19,39,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-05-02'),
  (92,57,'Lorem ipsum','20-10-13'),
  (67,12,'Lorem ipsum dolor sit','21-01-05'),
  (32,49,'Lorem ipsum dolor sit','21-01-08'),
  (7,54,'Lorem ipsum dolor sit amet,','20-12-21'),
  (2,37,'Lorem ipsum dolor sit amet,','20-06-28'),
  (66,32,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-02-10'),
  (29,44,'Lorem ipsum dolor','20-12-01'),
  (55,16,'Lorem ipsum dolor sit','20-01-04'),
  (9,47,'Lorem ipsum','20-12-12'),
  (68,32,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-10-15'),
  (35,24,'Lorem ipsum dolor sit amet,','21-01-05'),
  (10,40,'Lorem ipsum dolor','20-12-18'),
  (74,17,'Lorem ipsum','20-07-17'),
  (26,29,'Lorem ipsum dolor sit amet, consectetuer','20-05-29'),
  (83,36,'Lorem ipsum dolor sit','20-05-31'),
  (11,41,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-04-19'),
  (82,14,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-05-31');
INSERT INTO reviews (media_id,user_id,text,date)
VALUES
  (54,56,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-09-08'),
  (29,48,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-01-18'),
  (74,30,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-07-12'),
  (68,16,'Lorem ipsum dolor sit','21-03-13'),
  (5,25,'Lorem ipsum dolor sit amet,','21-03-06'),
  (6,10,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-06-30'),
  (82,29,'Lorem ipsum dolor sit amet, consectetuer adipiscing','21-01-13'),
  (19,18,'Lorem ipsum dolor sit amet, consectetuer adipiscing','21-02-03'),
  (96,25,'Lorem ipsum dolor sit amet,','20-03-17'),
  (69,26,'Lorem','20-02-06'),
  (38,52,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-08-26'),
  (83,53,'Lorem ipsum dolor','21-03-08'),
  (10,57,'Lorem ipsum dolor sit amet, consectetuer','20-07-12'),
  (40,26,'Lorem','20-04-26'),
  (34,37,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-09-27'),
  (53,50,'Lorem','21-01-13'),
  (50,30,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-08-28'),
  (38,24,'Lorem ipsum dolor','20-10-03'),
  (25,25,'Lorem ipsum dolor sit','20-10-20'),
  (63,36,'Lorem ipsum dolor sit','20-06-19'),
  (61,20,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','21-01-15'),
  (62,56,'Lorem ipsum dolor sit amet,','21-03-21'),
  (46,32,'Lorem ipsum dolor','20-09-03'),
  (86,9,'Lorem ipsum','20-09-21'),
  (92,44,'Lorem ipsum','20-08-31'),
  (79,51,'Lorem ipsum dolor sit amet, consectetuer','21-01-29'),
  (79,50,'Lorem ipsum dolor sit amet, consectetuer adipiscing','21-01-07'),
  (67,16,'Lorem ipsum dolor sit','20-06-03'),
  (79,39,'Lorem ipsum dolor sit','20-12-02'),
  (28,34,'Lorem ipsum dolor','20-12-27'),
  (78,45,'Lorem ipsum dolor','20-11-01'),
  (22,22,'Lorem ipsum dolor sit amet,','20-11-06'),
  (95,50,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-03-05'),
  (59,12,'Lorem ipsum dolor sit','20-12-20'),
  (52,9,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-07-04'),
  (63,48,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','21-03-28'),
  (50,50,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-01-02'),
  (70,9,'Lorem ipsum dolor','20-02-20'),
  (48,37,'Lorem ipsum dolor sit amet, consectetuer','21-02-01'),
  (80,23,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-05-27'),
  (48,42,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','20-02-29'),
  (13,17,'Lorem ipsum dolor sit','20-06-27'),
  (78,55,'Lorem ipsum dolor sit amet,','21-02-14'),
  (64,34,'Lorem ipsum dolor sit amet, consectetuer adipiscing','20-12-13'),
  (36,30,'Lorem ipsum dolor sit','20-01-10'),
  (5,20,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','20-03-24'),
  (31,51,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','20-07-11'),
  (29,38,'Lorem ipsum dolor sit amet, consectetuer','20-01-24'),
  (74,12,'Lorem ipsum dolor sit amet,','20-08-31'),
  (26,56,'Lorem ipsum dolor','20-07-25');
 
--Material usages
INSERT INTO material_usage(material_id, user_id, date, license_id, rating) 
VALUES
    (1, 1, '2020-11-15', 1, 6),
    (2, 2, '2020-11-17', 1, NULL),
    (2, 3, '2020-11-19', 1, NULL),
    (3, 4, '2020-12-02', 2, NULL),
    (5, 1, '2020-12-03', 1, 4),
    (7, 4, '2020-12-03', 2, 5),
    (6, 3, '2020-12-03', 2, NULL),
    (6, 4, '2020-12-04', 2, 7),
    (4, 3, '2020-12-04', 2, 5),
    (8, 1, '2020-12-08', 1, 5),
    (1, 3, '2020-12-09', 1, NULL),
    (5, 4, '2020-12-09', 1, 1);

INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (135,15,'20-08-07',3,7),
  (172,42,'20-02-11',2,1),
  (118,17,'20-02-03',2,6),
  (104,21,'20-11-05',2,9),
  (86,9,'20-05-07',2,4),
  (347,52,'20-10-15',1,5),
  (160,32,'20-10-12',2,5),
  (136,33,'20-05-04',2,10),
  (39,26,'20-10-01',2,4),
  (293,56,'21-02-13',2,4),
  (108,54,'20-08-20',2,4),
  (304,37,'20-02-16',2,9),
  (159,40,'20-10-01',1,9),
  (21,23,'21-02-27',2,4),
  (311,33,'21-01-05',1,1),
  (71,44,'21-01-15',2,3),
  (183,57,'20-10-12',2,5),
  (359,46,'20-07-01',2,6),
  (143,16,'20-09-25',2,10),
  (204,55,'20-12-05',1,8),
  (394,29,'20-10-19',1,2),
  (40,50,'20-07-10',2,2),
  (223,17,'20-01-08',2,4),
  (359,24,'20-05-30',2,4),
  (243,52,'20-02-16',1,1),
  (115,15,'20-08-14',2,3),
  (296,55,'21-02-19',2,5),
  (306,30,'20-10-23',2,5),
  (296,22,'20-12-05',3,4),
  (166,56,'20-03-25',3,3),
  (99,28,'20-01-09',2,9),
  (277,24,'20-01-20',2,5),
  (79,51,'20-10-02',2,10),
  (204,49,'20-06-26',3,3),
  (76,27,'20-02-11',2,8),
  (359,43,'20-02-11',3,6),
  (281,9,'20-09-12',2,2),
  (261,43,'20-04-06',2,2),
  (142,51,'20-03-12',2,10),
  (2,18,'20-07-17',2,2),
  (119,44,'20-03-26',1,2),
  (18,28,'20-01-16',2,6),
  (41,32,'20-07-30',3,4),
  (291,23,'21-02-09',3,1),
  (113,53,'20-09-21',2,5),
  (258,51,'20-08-05',2,2),
  (333,50,'20-02-27',1,2),
  (149,51,'20-04-06',2,1),
  (100,38,'21-01-21',3,3),
  (211,57,'20-02-25',2,9);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (102,13,'20-04-19',2,7),
  (135,9,'20-05-06',2,6),
  (226,12,'20-09-05',2,5),
  (8,48,'21-02-25',3,3),
  (302,37,'20-04-14',1,8),
  (344,35,'20-12-09',1,1),
  (67,35,'20-01-09',1,9),
  (151,24,'20-08-29',2,7),
  (106,12,'20-11-08',1,5),
  (299,32,'21-01-03',2,8),
  (82,14,'20-07-08',1,6),
  (123,23,'20-08-02',2,6),
  (179,26,'20-08-18',2,3),
  (47,55,'20-12-03',2,6),
  (264,54,'20-10-03',2,5),
  (149,19,'20-02-07',2,7),
  (234,48,'20-03-30',2,8),
  (81,53,'20-05-30',1,1),
  (36,23,'20-05-14',3,6),
  (9,21,'20-10-20',3,8),
  (169,10,'20-11-23',3,3),
  (125,35,'20-09-11',2,5),
  (262,52,'20-07-11',2,3),
  (266,26,'20-08-03',1,7),
  (135,40,'20-11-23',2,2),
  (65,44,'20-01-28',2,2),
  (300,30,'20-07-10',3,7),
  (111,33,'20-05-11',3,4),
  (82,35,'20-09-19',2,9),
  (249,47,'20-11-30',2,3),
  (163,10,'20-07-05',2,6),
  (321,44,'20-07-22',1,6),
  (167,37,'20-04-01',1,8),
  (373,12,'21-02-08',2,4),
  (68,41,'20-04-01',1,3),
  (4,45,'20-04-09',3,7),
  (12,21,'20-08-29',1,10),
  (11,45,'20-08-25',3,5),
  (355,56,'20-04-30',3,4),
  (334,31,'21-01-27',2,6),
  (87,38,'20-01-23',1,3),
  (324,50,'21-01-03',2,8),
  (335,43,'20-10-24',2,5),
  (125,57,'20-08-13',2,1),
  (315,34,'20-07-12',2,8),
  (129,30,'21-02-03',2,4),
  (307,57,'20-01-09',1,6),
  (237,16,'21-02-17',1,9),
  (200,23,'21-02-04',1,1),
  (4,31,'21-02-17',3,7);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (251,41,'20-07-21',1,7),
  (107,31,'20-05-02',3,2),
  (42,50,'20-01-20',1,3),
  (304,49,'20-11-30',2,5),
  (87,46,'21-01-09',3,7),
  (217,18,'20-06-21',1,10),
  (156,36,'21-01-21',2,2),
  (121,13,'20-05-17',2,3),
  (7,39,'20-06-28',1,7),
  (316,38,'20-01-03',2,7),
  (227,34,'20-02-02',2,5),
  (134,20,'21-02-05',3,5),
  (354,40,'21-01-13',2,4),
  (131,56,'20-06-06',2,9),
  (347,54,'20-09-13',1,7),
  (249,14,'21-02-22',2,7),
  (74,33,'20-05-31',2,8),
  (353,17,'20-10-05',3,1),
  (108,13,'21-01-25',3,6),
  (361,12,'20-08-26',3,4),
  (29,45,'20-01-30',3,5),
  (275,50,'21-02-07',2,7),
  (179,30,'20-09-04',3,8),
  (359,44,'20-12-08',3,7),
  (119,29,'20-08-27',1,8),
  (97,53,'21-03-27',2,1),
  (137,11,'20-08-11',2,2),
  (65,26,'21-02-17',2,9),
  (245,48,'20-02-11',3,8),
  (59,44,'20-01-05',1,3),
  (390,39,'20-06-27',2,7),
  (97,37,'20-08-12',2,9),
  (88,52,'20-02-20',1,8),
  (290,33,'20-11-12',2,9),
  (124,17,'20-11-05',2,2),
  (372,40,'20-08-12',3,10),
  (24,40,'20-04-28',2,7),
  (40,56,'20-08-01',2,9),
  (324,28,'21-01-09',3,9),
  (257,51,'20-07-30',2,2),
  (102,30,'20-02-04',2,8),
  (29,57,'20-07-28',2,9),
  (24,50,'20-12-13',2,1),
  (256,35,'20-07-05',3,6),
  (256,56,'20-07-11',3,6),
  (348,54,'20-12-08',2,9),
  (270,36,'20-12-17',1,5),
  (262,15,'20-07-23',2,4),
  (223,47,'20-07-19',1,4),
  (55,34,'20-08-19',2,9);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (253,41,'20-05-28',2,5),
  (342,12,'20-07-24',2,10),
  (28,34,'20-11-03',3,10),
  (244,27,'20-09-04',3,1),
  (82,26,'20-07-16',2,6),
  (65,14,'20-03-21',2,6),
  (19,15,'21-03-01',1,1),
  (261,51,'20-06-18',2,5),
  (330,28,'20-05-31',2,8),
  (64,38,'20-05-16',2,6),
  (358,36,'20-03-01',3,1),
  (366,15,'20-05-16',1,9),
  (31,21,'20-06-02',3,3),
  (361,56,'20-11-12',2,4),
  (254,20,'20-03-15',2,3),
  (94,17,'20-11-05',2,5),
  (229,14,'20-09-07',2,9),
  (339,56,'20-08-30',3,7),
  (22,39,'20-09-11',1,2),
  (354,54,'20-03-22',3,6),
  (147,52,'20-10-31',2,1),
  (77,51,'20-10-09',1,3),
  (193,38,'20-03-29',2,7),
  (322,47,'20-10-16',2,8),
  (30,19,'20-11-10',2,5),
  (329,19,'20-10-19',1,4),
  (217,39,'21-02-10',2,6),
  (127,11,'20-02-29',1,6),
  (103,43,'20-11-26',2,2),
  (294,39,'20-01-22',1,2),
  (203,56,'20-10-02',3,3),
  (195,48,'20-01-18',2,7),
  (337,45,'20-04-17',3,8),
  (45,36,'20-01-04',1,10),
  (225,13,'20-08-09',2,1),
  (94,48,'20-05-15',2,6),
  (188,24,'20-01-06',3,2),
  (274,57,'21-01-26',2,5),
  (356,18,'20-11-07',3,1),
  (302,28,'21-02-25',2,6),
  (309,49,'21-02-10',2,7),
  (149,57,'21-02-07',3,8),
  (53,15,'20-11-07',1,2),
  (370,22,'20-03-03',1,4),
  (228,25,'21-02-13',1,7),
  (125,30,'20-10-10',2,3),
  (329,33,'21-03-09',2,6),
  (29,36,'20-10-31',1,2),
  (23,49,'20-09-10',2,6),
  (45,41,'21-01-28',2,10);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (353,54,'20-10-08',1,5),
  (325,16,'21-01-22',2,9),
  (157,47,'20-01-20',2,6),
  (277,56,'20-09-06',1,5),
  (58,32,'21-03-03',2,6),
  (227,36,'21-03-07',3,8),
  (290,41,'20-09-18',2,10),
  (63,37,'21-03-25',2,9),
  (346,29,'20-08-15',3,8),
  (27,46,'20-02-23',2,2),
  (230,39,'21-01-22',1,2),
  (393,49,'20-02-10',2,5),
  (241,14,'21-03-04',3,7),
  (230,28,'20-09-21',1,7),
  (272,44,'20-05-08',2,2),
  (303,24,'20-08-16',3,1),
  (319,33,'20-02-10',1,10),
  (345,18,'20-01-14',3,9),
  (380,51,'20-02-04',2,1),
  (400,34,'20-05-05',2,10),
  (184,18,'20-07-22',3,8),
  (309,25,'20-04-05',3,6),
  (74,52,'21-03-30',2,9),
  (122,53,'20-04-25',3,5),
  (73,15,'20-04-15',1,3),
  (394,25,'20-12-12',2,5),
  (381,56,'20-11-01',3,6),
  (84,35,'20-03-24',2,9),
  (318,57,'20-12-23',1,9),
  (147,21,'20-03-27',2,9),
  (44,15,'21-02-14',2,2),
  (100,42,'20-01-24',2,3),
  (121,32,'20-02-01',2,9),
  (251,13,'20-10-02',2,9),
  (305,9,'21-03-24',3,1),
  (286,28,'21-03-01',2,9),
  (59,56,'20-01-18',2,3),
  (228,27,'20-01-03',3,4),
  (278,14,'21-02-16',2,2),
  (345,25,'20-08-31',1,10),
  (305,16,'20-11-09',3,4),
  (287,42,'21-01-14',2,1),
  (131,29,'20-09-30',2,2),
  (334,32,'20-10-19',1,7),
  (213,50,'20-04-09',3,1),
  (238,30,'20-02-20',2,2),
  (55,56,'20-09-04',3,2),
  (228,44,'20-05-02',2,7);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (40,10,'20-10-16',1,5),
  (40,53,'20-02-29',3,9),
  (208,16,'20-06-21',2,8),
  (200,45,'20-01-25',1,7),
  (327,57,'20-01-05',1,6),
  (267,22,'20-06-16',3,8),
  (135,31,'20-01-10',3,2),
  (299,10,'20-02-19',3,4),
  (287,40,'20-08-21',2,6),
  (174,20,'20-01-17',1,7),
  (295,43,'20-02-28',2,3),
  (134,56,'20-10-05',1,10),
  (268,41,'21-02-13',1,6),
  (220,55,'20-01-08',1,3),
  (62,23,'20-01-04',3,7),
  (324,45,'20-09-05',2,7),
  (167,34,'20-06-30',2,10),
  (132,9,'20-03-15',1,6),
  (6,19,'21-01-02',2,5),
  (259,39,'21-02-24',2,4),
  (60,22,'20-11-28',2,1),
  (124,53,'21-01-20',1,4),
  (26,43,'20-03-08',1,3),
  (194,19,'20-06-12',1,2),
  (371,50,'20-12-09',2,8),
  (69,47,'21-01-22',3,9),
  (176,25,'21-03-06',2,3),
  (327,13,'20-04-11',2,2),
  (317,22,'21-03-16',1,7),
  (39,36,'21-03-16',3,4),
  (129,33,'20-01-02',3,6),
  (227,32,'20-05-20',3,3),
  (173,14,'20-01-29',3,3),
  (43,39,'21-03-27',1,6),
  (156,44,'20-10-20',2,10),
  (138,45,'20-11-14',2,7),
  (244,12,'20-09-28',2,4),
  (29,32,'20-12-15',1,2),
  (151,17,'20-12-04',1,5),
  (210,54,'20-09-03',3,7),
  (240,43,'20-05-22',3,6),
  (30,31,'20-04-01',2,9),
  (368,24,'20-12-23',3,10),
  (246,30,'20-12-12',2,7),
  (390,41,'20-05-26',3,4),
  (82,25,'21-03-19',1,6),
  (151,57,'20-11-30',3,4),
  (326,39,'20-01-17',2,6),
  (41,11,'20-06-30',1,1),
  (100,56,'20-10-05',3,3);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (156,27,'20-07-10',2,8),
  (10,21,'20-07-23',2,8),
  (47,28,'20-04-13',2,3),
  (376,26,'20-05-05',2,6),
  (196,42,'21-03-05',2,6),
  (81,49,'20-08-15',2,4),
  (269,13,'20-05-28',2,6),
  (278,40,'20-07-18',1,9),
  (175,26,'20-04-22',2,8),
  (63,39,'21-03-26',2,2),
  (400,51,'20-06-21',3,7),
  (23,33,'20-08-17',2,8),
  (5,54,'20-06-24',2,4),
  (146,27,'20-04-24',3,9),
  (380,30,'20-06-19',1,5),
  (390,53,'20-01-15',1,2),
  (314,49,'20-09-14',3,7),
  (104,16,'20-02-17',2,10),
  (69,11,'20-07-06',2,3),
  (67,39,'21-02-16',2,4),
  (343,11,'20-04-10',2,7),
  (137,13,'20-01-05',2,5),
  (131,43,'20-02-07',1,3),
  (334,13,'20-07-30',2,9),
  (319,47,'20-05-14',2,4),
  (353,57,'20-06-07',1,2),
  (207,16,'21-02-14',2,3),
  (127,40,'20-11-01',3,3),
  (221,29,'20-08-27',2,10),
  (276,58,'20-06-06',2,3),
  (266,34,'20-07-06',3,1),
  (315,47,'20-06-29',1,10),
  (76,40,'20-05-25',3,6),
  (313,49,'20-12-16',3,3),
  (327,16,'20-10-10',3,2),
  (186,53,'20-08-10',2,9),
  (362,11,'20-12-24',2,2),
  (127,37,'20-05-14',1,10),
  (162,10,'20-05-09',3,2),
  (247,52,'20-02-25',2,7),
  (355,42,'20-11-26',2,1),
  (57,20,'20-03-10',2,9),
  (148,10,'20-12-11',3,9),
  (49,48,'20-09-07',3,8),
  (116,43,'20-10-06',2,6),
  (338,28,'20-06-22',2,8),
  (284,17,'21-03-06',1,6),
  (31,17,'20-08-10',2,3),
  (330,48,'21-03-03',1,5),
  (51,49,'20-12-23',3,5);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (208,12,'20-02-16',3,8),
  (124,21,'20-12-22',3,9),
  (174,45,'20-03-03',2,3),
  (324,22,'20-03-30',2,8),
  (165,26,'20-06-20',2,2),
  (92,43,'20-05-16',3,8),
  (116,23,'20-11-20',2,5),
  (321,10,'20-03-18',3,9),
  (259,26,'20-02-19',2,8),
  (222,44,'20-12-23',1,2),
  (146,32,'20-06-15',2,5),
  (98,26,'20-07-12',2,5),
  (292,39,'20-06-25',3,2),
  (184,31,'21-02-22',1,7),
  (345,36,'20-05-05',3,9),
  (104,42,'20-09-14',2,9),
  (74,29,'20-12-09',2,2),
  (91,41,'20-08-22',2,9),
  (214,14,'20-02-19',3,2),
  (305,26,'21-02-17',1,5),
  (172,54,'20-06-22',2,3),
  (271,9,'20-11-30',3,2),
  (42,37,'20-05-21',3,5),
  (267,18,'20-08-11',2,7),
  (45,52,'20-04-05',3,10),
  (157,16,'20-05-14',1,4),
  (9,22,'21-01-30',2,2),
  (157,44,'21-03-06',1,7),
  (263,22,'21-03-19',3,8),
  (6,12,'21-01-18',2,10),
  (352,46,'21-03-12',3,3),
  (303,17,'20-09-04',1,2),
  (38,58,'20-08-21',3,9),
  (48,41,'20-04-06',2,5),
  (272,24,'20-03-20',2,9),
  (288,24,'20-04-11',2,4),
  (334,17,'20-02-05',3,9),
  (234,12,'20-05-14',1,4),
  (305,20,'20-06-07',1,5),
  (273,30,'20-09-11',2,3),
  (165,21,'20-05-27',2,8),
  (264,51,'20-11-21',2,7),
  (384,44,'20-10-25',3,7),
  (185,12,'21-01-18',1,3),
  (291,24,'20-12-25',1,7),
  (228,20,'20-06-25',3,3),
  (73,18,'20-04-13',1,4),
  (1,34,'20-11-25',2,9);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (92,28,'20-04-06',2,6),
  (84,12,'21-03-20',3,8),
  (95,41,'20-01-25',2,5),
  (159,26,'20-03-29',2,1),
  (60,40,'21-03-24',2,3),
  (170,45,'20-05-27',1,4),
  (17,36,'20-10-24',2,4),
  (110,42,'21-01-28',3,4),
  (246,36,'21-03-10',1,3),
  (58,23,'21-02-18',3,3),
  (64,24,'20-02-05',2,8),
  (142,20,'20-03-05',3,5),
  (338,21,'20-11-12',3,1),
  (119,23,'21-03-11',1,2),
  (86,41,'20-02-06',2,5),
  (1,23,'21-01-01',2,10),
  (300,32,'20-12-02',3,2),
  (383,22,'20-10-27',1,4),
  (261,27,'20-10-26',2,1),
  (185,47,'20-05-17',2,1),
  (393,38,'20-01-31',2,3),
  (358,23,'20-09-26',2,9),
  (303,36,'20-02-15',3,5),
  (163,21,'21-01-22',3,6),
  (384,24,'20-09-05',3,1),
  (355,27,'20-06-22',3,9),
  (398,42,'20-07-27',2,1),
  (128,27,'20-08-06',3,9),
  (126,36,'21-02-03',2,7),
  (98,45,'20-12-20',1,9),
  (21,54,'20-07-13',1,6),
  (151,16,'20-09-18',2,3),
  (300,27,'20-11-15',1,6),
  (216,47,'21-02-12',1,9),
  (216,31,'20-10-23',1,4),
  (294,38,'21-03-02',1,5),
  (67,32,'20-06-05',2,8),
  (188,30,'20-11-30',2,9),
  (189,42,'20-05-02',2,6),
  (47,29,'20-02-18',1,4),
  (18,26,'20-06-09',1,9),
  (24,22,'21-01-11',3,3),
  (378,11,'20-02-23',2,6),
  (143,15,'20-08-16',2,8),
  (189,16,'20-05-03',1,9),
  (325,21,'20-08-10',1,7),
  (101,39,'21-03-28',3,8),
  (108,31,'20-12-16',2,3),
  (176,31,'20-11-28',2,5),
  (382,20,'20-08-12',2,4);
INSERT INTO material_usage (material_id,user_id,date,license_id,rating)
VALUES
  (21,31,'21-03-09',2,8),
  (50,22,'20-01-11',2,2),
  (328,53,'21-01-16',3,6),
  (287,51,'20-03-11',2,4),
  (159,29,'20-11-28',1,9),
  (73,30,'20-09-06',2,9),
  (224,36,'20-02-23',3,6),
  (251,39,'21-02-09',2,4),
  (275,20,'20-03-18',3,5),
  (266,42,'20-11-21',2,2),
  (131,55,'21-02-10',1,9),
  (93,29,'20-03-16',1,6),
  (324,18,'20-06-07',2,10),
  (294,42,'20-01-07',2,7),
  (146,45,'20-06-08',3,9),
  (285,21,'20-08-17',3,3),
  (352,52,'20-03-24',3,2),
  (92,19,'20-08-19',3,7),
  (95,40,'20-12-12',2,8),
  (189,25,'20-10-10',3,7),
  (218,23,'21-02-01',1,3),
  (170,21,'21-02-17',3,5),
  (338,55,'20-08-09',3,1),
  (95,24,'20-09-17',3,6),
  (263,51,'20-04-01',1,5),
  (127,46,'20-01-26',3,4),
  (283,54,'20-11-10',1,1),
  (281,24,'20-07-19',2,3),
  (256,25,'21-02-07',2,4),
  (284,57,'20-02-26',3,6),
  (120,23,'20-09-06',3,6),
  (97,51,'20-09-25',2,3),
  (294,14,'20-07-15',1,4),
  (181,10,'20-06-28',1,5),
  (67,36,'20-07-27',2,7),
  (324,33,'20-02-10',2,9),
  (153,44,'20-02-17',2,7),
  (291,54,'20-05-02',2,7),
  (285,37,'21-03-31',2,2),
  (112,19,'21-03-10',2,7),
  (50,54,'20-10-24',1,9),
  (300,41,'20-01-06',2,7),
  (78,12,'20-06-13',1,6),
  (106,56,'20-10-11',3,9),
  (345,35,'20-02-14',2,3),
  (197,25,'20-06-08',1,3),
  (41,38,'20-09-09',1,2),
  (71,40,'20-09-23',3,10),
  (44,16,'20-09-04',1,3),
  (240,51,'20-08-14',3,9);
 
SELECT update.update_ratings();
SELECT update.update_use_count(); 
COMMIT; 
