@echo off
setlocal EnableDelayedExpansion

set "SERVERS=servers.txt"
set "PORTS=80 9080 9443 9043"
set "OUT=webshell_results.txt"

REM Output file should contain ONLY matches
type nul > "%OUT%"

echo ==== Scanning for "Commands with JSP" webshell on / and /cmd/ ====
echo Results file: %OUT%
echo.

for /f "usebackq delims=" %%S in ("%SERVERS%") do (
  call :PROCESS_SERVER "%%S"
)

echo.
echo Done.
endlocal
exit /b


:PROCESS_SERVER
set "HOST=%~1"
REM skip blank / comment
if "%HOST%"=="" exit /b
if "%HOST:~0,1%"=="#" exit /b

for %%P in (%PORTS%) do (
  call :CHECK "%HOST%" "%%P" "/"
  call :CHECK "%HOST%" "%%P" "/cmd/"
  timeout /t 1 >nul
)
exit /b


:CHECK
set "H=%~1"
set "P=%~2"
set "PATH=%~3"

REM Try HTTP then HTTPS (some apps on 9443/9043)
call :FETCH_AND_MATCH "http"  "%H%" "%P%" "%PATH%"
if "%MATCHED%"=="1" exit /b

call :FETCH_AND_MATCH "https" "%H%" "%P%" "%PATH%"
exit /b


:FETCH_AND_MATCH
set "MATCHED=0"
set "SCHEME=%~1"
set "H=%~2"
set "P=%~3"
set "PATH=%~4"

set "URL=%SCHEME%://%H%:%P%%PATH%"
set "TMP=%TEMP%\resp_%RANDOM%_%RANDOM%.tmp"

curl -k -s --connect-timeout 3 --max-time 8 "%URL%" > "%TMP%" 2>nul

REM If empty response, skip
for %%A in ("%TMP%") do if %%~zA==0 (
  del /q "%TMP%" >nul 2>&1
  exit /b
)

REM Require >=2 indicators (reduce false positives)
set /a HIT=0
findstr /i /c:"Commands with JSP" "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"name=""cmd"""      "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"<FORM METHOD=""POST""" "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"<textarea"         "%TMP%" >nul && set /a HIT+=1

if %HIT% GEQ 2 (
  set "MATCHED=1"
  echo [+] warning Web Shell found on %H%:%P%PATH%
  >>"%OUT%" echo [+] warning Web Shell found on %H%:%P%PATH%
)

del /q "%TMP%" >nul 2>&1
exit /b
