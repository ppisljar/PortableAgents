@echo off
REM PortableAgents — launch the bundled portable Chrome (Chrome for Testing).
REM The profile is kept on the drive so browsing state travels with it.
REM Any arguments pass through to Chrome, e.g.:  chrome.bat https://example.com
setlocal
set "ROOT=%~dp0"
set "T=win-x64"
set "CHROME=%ROOT%bin\%T%\chrome\chrome.exe"
if not exist "%CHROME%" ( echo No bundled Chrome for %T% - run build.sh first. & pause & exit /b 1 )
start "" "%CHROME%" --user-data-dir="%ROOT%config\chrome-profile" %*
