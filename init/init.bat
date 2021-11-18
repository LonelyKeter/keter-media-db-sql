@echo off
SETLOCAL
SET output="%~dp0init.sql"

echo SET SCHEMA 'public'; > %output%
type "%~dp0countries.sql" >> %output%

type "%~dp0users.sql" >> %output%
echo. >> %output%
type "%~dp0authors.sql" >> %output%
echo. >> %output%
type "%~dp0mediaproducts.sql" >> %output%
echo. >> %output%
type "%~dp0licenses.sql" >> %output%
echo. >> %output%
type "%~dp0materials.sql" >> %output%
echo. >> %output%
type "%~dp0reviews.sql" >> %output%
echo. >> %output%
type "%~dp0material_usages.sql" >> %output%
echo. >> %output%
type "%~dp0call_updates.sql" >> %output%
ENDLOCAL