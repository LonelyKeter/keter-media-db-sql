@echo off

echo SET SCHEMA 'public'; > "%~dp0init.sql"
type "%~dp0users.sql" >> "%~dp0init.sql"