--super user
GRANT ALL ON DATABASE ketermedia TO ketermediasuperuser;

--unauthenticated
GRANT CONNECT ON DATABASE ketermedia TO keter_media_unauthenticated;
GRANT USAGE ON SCHEMA unauthenticated TO keter_media_unauthenticated;; 

--user
GRANT CONNECT ON DATABASE ketermedia TO keter_media_user;
GRANT USAGE ON SCHEMA "user" TO keter_media_unauthenticated;; 

--author
GRANT CONNECT ON DATABASE ketermedia TO keter_media_author;

--moderator
GRANT CONNECT ON DATABASE ketermedia TO keter_media_moderator;

--admin
GRANT CONNECT ON DATABASE ketermedia TO keter_media_admin;

--auth
GRANT CONNECT ON DATABASE ketermedia TO keter_media_auth;

