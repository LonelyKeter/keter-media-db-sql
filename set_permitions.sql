--unauthenticated
GRANT CONNECT ON DATABASE ketermedia TO keter_media_unauthenticated;
GRANT USAGE ON SCHEMA unauthenticated TO keter_media_unauthenticated; 

--user
GRANT CONNECT ON DATABASE ketermedia TO keter_media_registered;
GRANT USAGE ON SCHEMA registered TO keter_media_registered; 

--author
GRANT CONNECT ON DATABASE ketermedia TO keter_media_author;

--moderator
GRANT CONNECT ON DATABASE ketermedia TO keter_media_moderator;

--admin
GRANT CONNECT ON DATABASE ketermedia TO keter_media_admin;

--auth
GRANT CONNECT ON DATABASE ketermedia TO keter_media_auth;
GRANT USAGE ON SCHEMA auth TO keter_media_auth; 

