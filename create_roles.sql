CREATE ROLE ketermediasuperuser WITH
    LOGIN PASSWORD 'ketermediasuperuser'
    CREATEROLE;

CREATE ROLE keter_media_unauthenticated WITH
    LOGIN PASSWORD 'unauthenticated'
    NOCREATEROLE;

CREATE ROLE keter_media_user WITH
    LOGIN PASSWORD 'keter_media_user'
    NOCREATEROLE;


CREATE ROLE keter_media_author WITH
    LOGIN PASSWORD 'keter_media_author'
    NOCREATEROLE;

CREATE ROLE keter_media_moderator WITH
    LOGIN PASSWORD 'keter_media_moderator'
    NOCREATEROLE;

CREATE ROLE keter_media_admin WITH
    LOGIN PASSWORD 'keter_media_admin'
    NOCREATEROLE;

CREATE ROLE keter_media_auth WITH
    LOGIN PASSWORD 'keter_media_auth'
    NOCREATEROLE;