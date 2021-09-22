@echo off

echo BEGIN; > "%~dp0deploy.sql"

call "%~dp0schemas\schemas.bat"

type "%~dp0create_db.sql" >> "%~dp0deploy.sql"

type "%~dp0schemas\schemas.sql" >> "%~dp0deploy.sql"

type "%~dp0create_roles.sql" >> "%~dp0deploy.sql"
type "%~dp0set_permitions.sql" >> "%~dp0deploy.sql"

call "%~dp0init\init.bat"
type "%~dp0init\init.sql" >> "%~dp0deploy.sql"

echo COMMIT; >> "%~dp0deploy.sql"