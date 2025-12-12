@echo off
setlocal EnableDelayedExpansion

set "SERVERS=servers.txt"
set "OUT=webshell_results.txt"

set "HTTP_PORTS=80 9080"
set "HTTPS_PORTS=9443 9043"
set "PATHS=/ /cmd/"

type nul > "%OUT%"

REM Get first valid host (you said only one server)
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

REM ---------- HTTP ports ----------
for %%P in (%HTTP_PORTS%) do (
  for %%X in (%PATHS%) do (
    set "URL=http://%HOST%:%%P%%X"
    call :CHECKURL "!URL!" "%HOST%" "%%P" "%%X"
  )
)

REM ---------- HTTPS ports ----------
for %%P in (%HTTPS_PORTS%) do (
  for %%X in (%PATHS%) do (
    set "URL=https://%HOST%:%%P%%X"
    call :CHECKURL "!URL!" "%HOST%" "%%P" "%%X"
  )
)

echo.
echo Done.
endlocal
exit /b


:CHECKURL
set "URL=%~1"
set "H=%~2"
set "P=%~3"
set "PATH=%~4"

set "TMP=%TEMP%\resp_%RANDOM%_%RANDOM%.tmp"
type nul > "%TMP%"

echo [*] GET %URL%

REM Capture HTTP status code reliably
set "CODE="
for /f "delims=" %%C in ('
  curl -k -s --connect-timeout 3 --max-time 8 -o "%TMP%" -w "%%{http_code}" "%URL%"
') do set "CODE=%%C"

REM Only consider 200 OK as a candidate
if not "%CODE%"=="200" (
  del /q "%TMP%" >nul 2>&1
  exit /b
)

REM Require BOTH indicators (reduces false positives hard)
findstr /i /c:"Commands with JSP" "%TMP%" >nul || (del /q "%TMP%" >nul 2>&1 & exit /b)
findstr /i /c:"name=""cmd"""      "%TMP%" >nul || (del /q "%TMP%" >nul 2>&1 & exit /b)

echo [+] warning Web Shell found on %H%:%P%PATH%
>>"%OUT%" echo [+] warning Web Shell found on %H%:%P%PATH%

del /q "%TMP%" >nul 2>&1
exit /b
