@echo off
setlocal EnableDelayedExpansion

set SERVERS=servers.txt
set PATHS=was_search.txt
set PORTS=80 9080 9443 9043

REM Strong indicators from your sample page:
set IND1=Commands with JSP
set IND2=name="cmd"
set IND3=<FORM METHOD="POST"
set IND4=<textarea

echo ==== Detect "Commands with JSP" in HTTP responses ====
echo.

for /f "usebackq delims=" %%S in ("%SERVERS%") do (
  set "HOST=%%S"
  if "!HOST!"=="" goto :nextServer
  if "!HOST:~0,1!"=="#" goto :nextServer

  for %%P in (%PORTS%) do (
    for /f "usebackq tokens=1 delims= " %%E in ("%PATHS%") do (
      set "PATH=%%E"
      if "!PATH!"=="" goto :nextPath
      if "!PATH:~0,1!"=="#" goto :nextPath

      REM Ensure path starts with /
      if not "!PATH:~0,1!"=="/" set "PATH=/!PATH!"

      set "URL=http://!HOST!:%%P!PATH!"
      set "TMP=%TEMP%\resp_!HOST!_%%P.tmp"

      REM Fetch body (silent), store to temp file
      curl -k -s --max-time 8 "!URL!" > "!TMP!" 2>nul

      REM Require at least 2 indicators to reduce false positives
      findstr /i /c:"!IND1!" "!TMP!" >nul
      set "M1=!errorlevel!"
      findstr /i /c:"!IND2!" "!TMP!" >nul
      set "M2=!errorlevel!"
      findstr /i /c:"!IND3!" "!TMP!" >nul
      set "M3=!errorlevel!"
      findstr /i /c:"!IND4!" "!TMP!" >nul
      set "M4=!errorlevel!"

      set /a HIT=0
      if "!M1!"=="0" set /a HIT+=1
      if "!M2!"=="0" set /a HIT+=1
      if "!M3!"=="0" set /a HIT+=1
      if "!M4!"=="0" set /a HIT+=1

      if !HIT! GEQ 2 (
        echo [MATCH] !URL!  ^(indicators=!HIT!^)
        REM Show the matching lines for quick validation
        findstr /i ^
          /c:"Commands with JSP" ^
          /c:"name=""cmd""" ^
          /c:"<FORM METHOD=""POST""" ^
          /c:"<textarea" "!TMP!"
        echo.
      )

      del /q "!TMP!" >nul 2>&1

      :nextPath
    )
  )

  :nextServer
)

endlocal
