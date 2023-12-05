@echo off
setlocal

set SRCDIR=%~dp0
set CPPFLAGS=/DWIN32
set ENABLE_ICU=yes
set ENABLE_ICU_DLL=yes

:argloop
shift
set ARG=%0
if defined ARG (
  if "%ARG%"=="/disableicu" set ENABLE_ICU=no && goto argloop
  if "%ARG%"=="/disableicudll" set ENABLE_ICU_DLL=no && goto argloop
  echo Unrecognized argument %ARG%
  exit /B 1
)

if %ENABLE_ICU%==yes set CPPFLAGS="%CPPFLAGS% /DRKTIO_HAVE_ICU"
if %ENABLE_ICU_DLL%==yes set CPPFLAGS="%CPPFLAGS% /DRKTIO_ICU_DLL"

copy /y "%SRCDIR%\buildmain.zuo" main.zuo > NUL
echo srcdir=%SRCDIR% > Makefile
echo CFLAGS=/Ox >> Makefile

cl.exe /nologo /Fe: winfig.exe "%SRCDIR%\..\..\worksp\winfig.c"
winfig.exe >> Makefile
