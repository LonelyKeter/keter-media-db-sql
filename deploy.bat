@echo off
SETLOCAL
SET output="%~dp0deploy.sql"

echo BEGIN; > %output%

call "%~dp0schemas\schemas.bat"
echo. >> %output%
type "%~dp0schemas\schemas.sql" >> %output%

echo. >> %output%
type "%~dp0create_roles.sql" >> %output%
echo. >> %output%
type "%~dp0set_permitions.sql" >> %output%

call "%~dp0init\init.bat"
echo. >> %output%
type "%~dp0init\init.sql" >> %output%

echo. >> %output%
echo COMMIT; >> %output%

ENDLOCAL