@echo off
setlocal EnableExtensions

set "CONFIG=%~1"
set "PLATFORM=%~2"
if "%CONFIG%"=="" set "CONFIG=Release"
if "%PLATFORM%"=="" set "PLATFORM=x64"

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "WORK=%ROOT%\build\vs2022\selfhost\%CONFIG%-%PLATFORM%"
set "OUT=%ROOT%\build\bin\%CONFIG%-%PLATFORM%"

if /I "%~3"=="clean" (
  if exist "%WORK%" rmdir /S /Q "%WORK%"
  if exist "%OUT%" rmdir /S /Q "%OUT%"
  exit /B 0
)

where cl.exe >NUL 2>NUL
if errorlevel 1 (
  echo CMotive self-host build requires a Visual Studio 2022 Developer Command Prompt. 1>&2
  exit /B 2
)

if not exist "%WORK%" mkdir "%WORK%"
if not exist "%OUT%" mkdir "%OUT%"

set "OPT=/O2"
if /I "%CONFIG%"=="Debug" set "OPT=/Od /Zi"
set "COMMON=/nologo /std:c17 /TC /W3 /D_CRT_SECURE_NO_WARNINGS %OPT%"

cl %COMMON% /Fo"%WORK%\cmotive-stage0.obj" /Fe"%WORK%\cmotive-stage0.exe" "%ROOT%\bootstrap\c\cmotive_bootstrap.c"
if errorlevel 1 exit /B 1

"%WORK%\cmotive-stage0.exe" --emit-c "%ROOT%\src\frontend\selfhost\CMotiveFrontend.CMOT" -o "%WORK%\CMotiveFrontend.stage1.c"
if errorlevel 1 exit /B 1

cl %COMMON% /I"%ROOT%" /I"%ROOT%\lib\Sys" /Fo"%WORK%\cmotive-stage1.obj" /Fe"%WORK%\cmotive-stage1.exe" "%WORK%\CMotiveFrontend.stage1.c" /link ws2_32.lib
if errorlevel 1 exit /B 1

"%WORK%\cmotive-stage1.exe" --emit-c "%ROOT%\src\frontend\selfhost\CMotiveFrontend.CMOT" -o "%WORK%\CMotiveFrontend.stage2.c"
if errorlevel 1 exit /B 1

cl %COMMON% /I"%ROOT%" /I"%ROOT%\lib\Sys" /Fo"%WORK%\cmotive-stage2.obj" /Fe"%OUT%\cmotive.exe" "%WORK%\CMotiveFrontend.stage2.c" /link ws2_32.lib
if errorlevel 1 exit /B 1

copy /Y "%OUT%\cmotive.exe" "%OUT%\cmotivepp.exe" >NUL
copy /Y "%OUT%\cmotive.exe" "%OUT%\cmotive++.exe" >NUL
copy /Y "%OUT%\cmotive.exe" "%OUT%\CMotiveSymsToDebugFile.exe" >NUL

"%OUT%\cmotive.exe" --emit-c "%ROOT%\src\tools\CToCMotive.CMOT" -o "%WORK%\CToCMotive.c"
if errorlevel 1 exit /B 1

cl %COMMON% /I"%ROOT%" /I"%ROOT%\lib\Sys" /Fo"%WORK%\c2cmotive.obj" /Fe"%OUT%\c2cmotive.exe" "%WORK%\CToCMotive.c" /link ws2_32.lib
if errorlevel 1 exit /B 1

"%OUT%\cmotive.exe" --emit-c "%ROOT%\src\frontend\selfhost\CMotiveFrontend.CMOT" -o "%WORK%\CMotiveFrontend.stage3.c"
if errorlevel 1 exit /B 1

fc /B "%WORK%\CMotiveFrontend.stage1.c" "%WORK%\CMotiveFrontend.stage2.c" >NUL
if errorlevel 1 (
  echo CMotive stage-1 and stage-2 generated C differ. 1>&2
  exit /B 1
)
fc /B "%WORK%\CMotiveFrontend.stage2.c" "%WORK%\CMotiveFrontend.stage3.c" >NUL
if errorlevel 1 (
  echo CMotive stage-2 and stage-3 generated C differ. 1>&2
  exit /B 1
)

(
  echo configuration=%CONFIG%
  echo platform=%PLATFORM%
  echo frontend=%OUT%\cmotive.exe
  echo converter=%OUT%\c2cmotive.exe
  echo fixed_point=PASS
) > "%WORK%\BUILD_OUTPUTS.txt"

echo CMotive self-host VS2022 build: PASS
exit /B 0
