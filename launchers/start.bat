@echo off
REM PortableAgents launcher (Windows) — claude/codex/git/python/chrome on PATH, config on the drive.
setlocal
set "ROOT=%~dp0"
set "T=win-x64"
set "B=%ROOT%bin\%T%"
if not exist "%B%\node\node.exe" ( echo No bundled Node for %T% - run build.sh first. & pause & exit /b 1 )

set "CHROME=%B%\chrome\chrome.exe"
set "PATH=%B%\node;%B%\git\cmd;%B%\git\mingw64\bin;%B%\python;%ROOT%tools\%T%\shims;%PATH%"
set "CHROME_BIN=%CHROME%"
set "PUPPETEER_EXECUTABLE_PATH=%CHROME%"
set "CHROME_PATH=%CHROME%"
set "CLAUDE_CONFIG_DIR=%ROOT%config\.claude"
set "XDG_CONFIG_HOME=%ROOT%config"
set "TMP=%ROOT%temp"
set "TEMP=%ROOT%temp"
set "NPM_CONFIG_CACHE=%ROOT%temp\npm-cache"
set "PIP_CACHE_DIR=%ROOT%temp\pip-cache"
if not exist "%ROOT%temp" mkdir "%ROOT%temp"

REM --- patch project paths for this mount point (portable across OS/mounts) -------
set "ROOT_NT=%ROOT:~0,-1%"
powershell -NoProfile -Command "$r='%ROOT_NT%'; @('projects_list.json','project_config.yaml')|%%{$f=\"$r\config\.claude\$_\" ; if(Test-Path $f){(Get-Content $f -Raw)-replace '__ROOT__',$r|Set-Content $f -NoNewline}}"

if exist "%ROOT%config\env.bat" call "%ROOT%config\env.bat"

echo ======================================
echo   PortableAgents (win-x64)
echo   claude ^| codex ^| git ^| python ^| node
echo   chrome at: %CHROME%
echo   web app:   start_web.bat
echo ======================================
if "%ANTHROPIC_API_KEY%"=="YOUR_KEY_HERE" echo   (no API key set - 'claude' will prompt OAuth login)
cmd /k
