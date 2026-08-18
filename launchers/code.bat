@echo off
REM PortableAgents — launch the bundled portable VS Code.
REM User data (settings, extensions) is kept on the drive via VS Code's portable mode.
REM With no argument it opens the drive root; otherwise args pass through, e.g.:  code.bat myproject
setlocal
set "ROOT=%~dp0"
set "T=win-x64"
set "CODE=%ROOT%bin\%T%\vscode\bin\code.cmd"
if not exist "%CODE%" ( echo No bundled VS Code for %T% - run build.sh first. & pause & exit /b 1 )
if "%~1"=="" ( call "%CODE%" "%ROOT%." ) else ( call "%CODE%" %* )
