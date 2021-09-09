--unauthenticated
GRANT CONNECT ON DATABASE ketermedia TO keter_media_unauthenticated;
GRANT USAGE ON SCHEMA unauthenticated TO keter_media_unauthenticated; 
GRANT SELECT ON ALL TABLES IN SCHEMA unauthenticated TO keter_media_unauthenticated;

--user
GRANT CONNECT ON DATABASE ketermedia TO keter_media_registered;
GRANT USAGE ON SCHEMA registered TO keter_media_registered; 

GRANT SELECT ON ALL TABLES IN SCHEMA registered TO keter_media_registered;

--author
GRANT CONNECT ON DATABASE ketermedia TO keter_media_author;

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
