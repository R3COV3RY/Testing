@echo off
setlocal EnableDelayedExpansion

set "SERVERS=servers.txt"
set "OUT=webshell_results.txt"
set "HOST="

type nul > "%OUT%"

REM Get the first valid server line
for /f "usebackq delims=" %%S in ("%SERVERS%") do (
  set "L=%%S"
  if not "!L!"=="" if not "!L:~0,1!"=="#" (
    set "HOST=!L!"
    goto :GOT_HOST
  )
)

echo No valid host found in %SERVERS%
exit /b 1

:GOT_HOST
echo Testing host: %HOST%
echo Results file: %OUT%
echo.

call :CHECK_PORT 80
call :CHECK_PORT 9080
call :CHECK_PORT 9443
call :CHECK_PORT 9043

echo.
echo Done.
endlocal
exit /b


:CHECK_PORT
set "P=%~1"

REM HTTP always
call :CHECK_URL "http"  "%HOST%" "%P%" "/"
call :CHECK_URL "http"  "%HOST%" "%P%" "/cmd/"

REM HTTPS only on 9443/9043
if "%P%"=="9443" (
  call :CHECK_URL "https" "%HOST%" "%P%" "/"
  call :CHECK_URL "https" "%HOST%" "%P%" "/cmd/"
)
if "%P%"=="9043" (
  call :CHECK_URL "https" "%HOST%" "%P%" "/"
  call :CHECK_URL "https" "%HOST%" "%P%" "/cmd/"
)

exit /b


:CHECK_URL
set "SCHEME=%~1"
set "H=%~2"
set "P=%~3"
set "PATH=%~4"

set "URL=%SCHEME%://%H%:%P%%PATH%"
set "TMP=%TEMP%\resp_%RANDOM%_%RANDOM%.tmp"

echo [*] GET %URL%

REM Fast timeouts so nothing "hangs"
curl -k -sS --connect-timeout 2 --max-time 5 "%URL%" > "%TMP%" 2>nul

REM If curl failed or empty, skip
for %%A in ("%TMP%") do if %%~zA==0 (
  del /q "%TMP%" >nul 2>&1
  exit /b
)

REM Look for your exact indicators (need >=2)
set /a HIT=0
findstr /i /c:"Commands with JSP" "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"name=""cmd"""      "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"<FORM METHOD=""POST""" "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"<textarea"         "%TMP%" >nul && set /a HIT+=1

if !HIT! GEQ 2 (
  echo [+] warning Web Shell found on %H%:%P%PATH%
  >>"%OUT%" echo [+] warning Web Shell found on %H%:%P%PATH%
)

del /q "%TMP%" >nul 2>&1
exit /b
