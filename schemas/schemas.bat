@echo off
type "%~dp0public.sql" > "%~dp0schemas.sql"
type "%~dp0auth.sql" >> "%~dp0schemas.sql"
type "%~dp0unauthenticated.sql" >> "%~dp0schemas.sql"
type "%~dp0registered.sql" >> "%~dp0schemas.sql"
type "%~dp0author.sql" >> "%~dp0schemas.sql"
type "%~dp0moderator.sql" >> "%~dp0schemas.sql"
type "%~dp0admin.sql" >> "%~dp0schemas.sql"
type "%~dp0test.sql" >> "%~dp0schemas.sql"