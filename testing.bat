@echo off
setlocal EnableDelayedExpansion

set "SERVERS=servers.txt"
set "OUT=webshell_results.txt"

set "HTTP_PORTS=80 9080"
set "HTTPS_PORTS=9443 9043"
set "PATHS=/cmd/ /"

type nul > "%OUT%"

REM Get first valid host (since you have only one test server)
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

REM ---- HTTP ports ----
for %%P in (%HTTP_PORTS%) do (
  for %%X in (%PATHS%) do (
    set "URL=http://%HOST%:%%P%%X"
    echo [*] GET !URL!
    curl -k -s --connect-timeout 3 --max-time 8 "!URL!" > "%TEMP%\resp.tmp"
    findstr /i /c:"Commands with JSP" "%TEMP%\resp.tmp" >nul
    if !errorlevel! EQU 0 (
      echo [+] warning Web Shell found on %HOST%:%%P%%X
      >>"%OUT%" echo [+] warning Web Shell found on %HOST%:%%P%%X
    )
  )
)

REM ---- HTTPS ports ----
for %%P in (%HTTPS_PORTS%) do (
  for %%X in (%PATHS%) do (
    set "URL=https://%HOST%:%%P%%X"
    echo [*] GET !URL!
    curl -k -s --connect-timeout 3 --max-time 8 "!URL!" > "%TEMP%\resp.tmp"
    findstr /i /c:"Commands with JSP" "%TEMP%\resp.tmp" >nul
    if !errorlevel! EQU 0 (
      echo [+] warning Web Shell found on %HOST%:%%P%%X
      >>"%OUT%" echo [+] warning Web Shell found on %HOST%:%%P%%X
    )
  )
)

del /q "%TEMP%\resp.tmp" >nul 2>&1

echo.
echo Done.
endlocal
exit /b
