@echo off
setlocal EnableDelayedExpansion

set "SERVERS=servers.txt"
set "PORTS=80 9080 9443 9043"

echo ==== Detect "Commands with JSP" page on / and /cmd/ ====
echo.

for /f "usebackq delims=" %%S in ("%SERVERS%") do (
  set "HOST=%%S"
  if "!HOST!"=="" goto :nextServer
  if "!HOST:~0,1!"=="#" goto :nextServer

  for %%P in (%PORTS%) do (
    call :CHECKURL "http://!HOST!:%%P/"
    call :CHECKURL "http://!HOST!:%%P/cmd/"
    call :CHECKURL "https://!HOST!:%%P/"
    call :CHECKURL "https://!HOST!:%%P/cmd/"

    REM throttle
    timeout /t 1 >nul
  )

  :nextServer
)

endlocal
goto :eof

:CHECKURL
set "URL=%~1"
set "TMP=%TEMP%\resp_%RANDOM%.tmp"

curl -k -s --connect-timeout 3 --max-time 8 "%URL%" > "%TMP%" 2>nul

REM If empty file, skip quietly
for %%A in ("%TMP%") do if %%~zA==0 (
  del /q "%TMP%" >nul 2>&1
  goto :eof
)

REM Count indicators (require >=2)
set /a HIT=0
findstr /i /c:"Commands with JSP" "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"name=""cmd"""      "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"<FORM METHOD=""POST""" "%TMP%" >nul && set /a HIT+=1
findstr /i /c:"<textarea"         "%TMP%" >nul && set /a HIT+=1

if !HIT! GEQ 2 (
  echo [MATCH] %URL%  ^(indicators=!HIT!^)
  findstr /i ^
    /c:"Commands with JSP" ^
    /c:"name=""cmd""" ^
    /c:"<FORM METHOD=""POST""" ^
    /c:"<textarea" "%TMP%"
  echo.
)

del /q "%TMP%" >nul 2>&1
goto :eof
