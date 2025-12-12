@echo off
setlocal EnableDelayedExpansion

REM ===== CONFIG =====
set PORTS=80 9080 9443 9043
set SERVERS=servers.txt
set PATHS=was_search.txt
set OUT=websphere_security_report_curl.txt

REM ===== INIT REPORT =====
echo WebSphere curl security report > %OUT%
echo Generated: %DATE% %TIME% >> %OUT%
echo ============================================ >> %OUT%

REM ===== LOOP SERVERS =====
for /f "usebackq delims=" %%S in ("%SERVERS%") do (
    set HOST=%%S

    for %%P in (%PORTS%) do (
        echo. >> %OUT%
        echo ==== !HOST!:%%P ==== >> %OUT%

        REM ----- BASE REQUEST (HEADERS) -----
        curl -k -s -I http://!HOST!:%%P >> %OUT%

        REM ----- TITLE -----
        for /f "delims=" %%T in ('
            curl -k -s http://!HOST!:%%P ^| findstr /i "<title>"
        ') do (
            echo TITLE: %%T >> %OUT%
        )

        REM ----- HTTP METHODS -----
        echo --- Allowed Methods --- >> %OUT%
        curl -k -s -i -X OPTIONS http://!HOST!:%%P | findstr /i "Allow:" >> %OUT%

        REM ----- ENUM PATHS -----
        echo --- Enum Paths --- >> %OUT%
        for /f "tokens=1" %%E in (%PATHS%) do (
            curl -k -s -o NUL -w "%%E : %%{http_code}\n" http://!HOST!:%%P%%E >> %OUT%
        )

        REM ----- THROTTLE -----
        timeout /t 1 >nul
    )
)

echo Done. Report saved to %OUT%
endlocal
