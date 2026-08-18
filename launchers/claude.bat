@echo off
REM PortableAgents — Claude Code with default Anthropic API.
REM Any arguments pass through to claude, e.g.:  claude.bat -p "hello"
setlocal
set "ROOT=%~dp0"
set "T=win-x64"
set "B=%ROOT%bin\%T%"
if not exist "%B%\node\node.exe" ( echo No bundled Node for %T% - run build.sh first. & pause & exit /b 1 )

REM --- PATH + bundled runtimes ------------------------------------------------
set "CHROME=%B%\chrome\chrome.exe"
REM shims first: the drive's own launchers must outrank anything npm drops into bin\node
set "PATH=%ROOT%tools\%T%\shims;%B%\extras;%B%\node;%B%\git\cmd;%B%\git\mingw64\bin;%B%\python;%PATH%"
set "CHROME_BIN=%CHROME%"
set "PUPPETEER_EXECUTABLE_PATH=%CHROME%"
set "CHROME_PATH=%CHROME%"

REM --- config + cache stay on the drive ---------------------------------------
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

REM --- default env (API keys — set your real keys or use OAuth login) ----------
if not defined CLAUDE_ENV set "CLAUDE_ENV=%ROOT%config\env.bat"
if exist "%CLAUDE_ENV%" call "%CLAUDE_ENV%"

echo  PortableAgents (win-x64)
cd /d "%USERPROFILE%"
claude %*
