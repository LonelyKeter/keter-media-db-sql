@echo off
SETLOCAL
SET output="%~dp0schemas.sql"

echo. >> %output%
type "%~dp0public.sql" > %output%
echo. >> %output%
type "%~dp0auth.sql" >> %output%
echo. >> %output%
type "%~dp0unauthenticated.sql" >> %output%
echo. >> %output%
type "%~dp0registered.sql" >> %output%
echo. >> %output%
type "%~dp0author.sql" >> %output%
echo. >> %output%
type "%~dp0moderator.sql" >> %output%
echo. >> %output%
type "%~dp0admin.sql" >> %output%
echo. >> %output%
type "%~dp0test.sql" >> %output%
ENDLOCAL