@echo off
REM PortableAgents — launch the Claude session-viewer web app with bundled Node.
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

REM --- patch project paths for this mount point (portable across OS/mounts) -------
set "ROOT_NT=%ROOT:~0,-1%"
powershell -NoProfile -Command "$r='%ROOT_NT%'; @('projects_list.json','project_config.yaml')|%%{$f=\"$r\config\.claude\$_\" ; if(Test-Path $f){(Get-Content $f -Raw)-replace '__ROOT__',$r|Set-Content $f -NoNewline}}"

cd /d "%ROOT%config\.claude\app"
if not exist package.json ( echo web app not found & pause & exit /b 1 )
if exist server-dist\index.js if exist dist\index.html (
  echo ======================================
  echo   Claude session viewer ^(built^) - starting...
  echo ======================================
  node server-dist\index.js
  goto :eof
)
if not exist node_modules ( echo ==^> first run: installing web app deps... & call npm install --no-audit --no-fund )
echo   ^(no prebuilt app - starting dev mode; Vite prints the URL^)
call npm run dev
