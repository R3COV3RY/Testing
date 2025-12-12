@echo off
setlocal EnableDelayedExpansion

set "SERVERS=servers.txt"
set "OUT=webshell_results.txt"

REM Ports
set "HTTP_PORTS=80 9080"
set "HTTPS_PORTS=9443 9043"

REM Only output matches in file
type nul > "%OUT%"

REM Read first valid server (since you said only one for testing)
set "HOST="
for /f "usebackq delims=" %%S in ("%SERVERS%") do (
  set "L=%%S"
  if not "!L!"=="" if not "!L:~0,1!"=="#" (
    set "HOST=!L!"
    goto :GOT
  )
)
echo No valid host found in %SERVERS%
exit /b 1

:GOT
echo Testing host: %HOST%
echo Results file: %OUT%
echo.

REM HTTP ports: try /cmd/ then /
for %%P in (%HTTP_PORTS%) do (
  call :TRY_ONE "http" "%HOST%" "%%P" "/cmd/"
  call :TRY_ONE "http" "%HOST%" "%%P" "/"
)

REM HTTPS ports: try /cmd/ then /
for %%P in (%HTTPS_PORTS%) do (
  call :TRY_ONE "https" "%HOST%" "%%P" "/cmd/"
  call :TRY_ONE "https" "%HOST%" "%%P" "/"
)

echo.
echo Done.
endlocal
exit /b


:TRY_ONE
set "SCHEME=%~1"
set "H=%~2"
set "P=%~3"
set "PATH=%~4"

set "URL=%SCHEME%://%H%:%P%%PATH%"
set "TMP=%TEMP%\resp_%RANDOM%_%RANDOM%.tmp"

echo [*] GET %URL%

REM Use -s (not -sS) so curl doesn't change behavior; keep timeouts small
curl -k -s --connect-timeout 3 --max-time 8 "%URL%" > "%TMP%"

REM If response contains the key phrase, it's a match
findstr /i /c:"Commands with JSP" "%TMP%" >nul
if %errorlevel%==0 (
  echo [+] warning Web Shell found on %H%:%P%PATH%
  >>"%OUT%" echo [+] warning Web Shell found on %H%:%P%PATH%
)

del /q "%TMP%" >nul 2>&1
exit /b
