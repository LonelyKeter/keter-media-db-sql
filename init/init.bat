@echo off

echo SET SCHEMA 'public'; > "%~dp0init.sql"
type "%~dp0countries.sql" >> "%~dp0init.sql"
type "%~dp0users.sql" >> "%~dp0init.sql"
type "%~dp0authors.sql" >> "%~dp0init.sql"
type "%~dp0mediaproducts.sql" >> "%~dp0init.sql"
type "%~dp0licenses.sql" >> "%~dp0init.sql"
type "%~dp0materials.sql" >> "%~dp0init.sql"