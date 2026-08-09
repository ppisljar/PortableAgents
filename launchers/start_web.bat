@echo off
REM PortableClaude — launch the Claude session-viewer web app with bundled Node.
setlocal
set "ROOT=%~dp0"
set "T=win-x64"
set "B=%ROOT%bin\%T%"
if not exist "%B%\node\node.exe" ( echo No bundled Node - run build.sh first. & pause & exit /b 1 )
set "PATH=%B%\node;%B%\git\cmd;%B%\python;%PATH%"
set "TMP=%ROOT%temp"
set "TEMP=%ROOT%temp"
set "NPM_CONFIG_CACHE=%ROOT%temp\npm-cache"
if not exist "%ROOT%temp" mkdir "%ROOT%temp"

cd /d "%ROOT%config\.claude\app"
if not exist package.json ( echo web app not found & pause & exit /b 1 )
if not exist node_modules ( echo ==^> first run: installing web app deps... & call npm install --no-audit --no-fund )
echo ======================================
echo   Claude session viewer - starting...
echo   (Vite will print the local URL below)
echo ======================================
call npm run dev
