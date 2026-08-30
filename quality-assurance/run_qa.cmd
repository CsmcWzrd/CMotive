@echo off
setlocal
set ROOT=%~dp0..
if "%~1"=="" (
  set BINDIR=%ROOT%\build\bin
) else (
  set BINDIR=%~1
)
where sh >nul 2>nul
if errorlevel 1 (
  echo CMotive QA requires a POSIX-compatible shell such as Git Bash, MSYS2, or WSL.
  exit /b 2
)
sh "%~dp0run_qa.sh" "%BINDIR%" ".exe"
exit /b %ERRORLEVEL%
