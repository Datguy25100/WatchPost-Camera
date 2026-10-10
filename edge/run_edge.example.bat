@echo off
REM Copy this file to run_edge.bat, fill in the 3 values, then double-click it.
set WATCHPOST_URL=https://YOUR-NAME.app.n8n.cloud/webhook/watchpost
set WATCHPOST_KEY=PUT-YOUR-INGEST_KEY-HERE
set PHONE=192.168.1.50:8080

cd /d "%~dp0"
:loop
python edge.py --camera "Front door" --ip-webcam %PHONE% --ai --faces faces --sync-interval 120
echo edge.py stopped, restarting in 10s (close this window to quit)...
timeout /t 10 >nul
goto loop
