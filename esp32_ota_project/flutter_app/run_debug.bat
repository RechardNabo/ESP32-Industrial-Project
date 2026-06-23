@echo off
cd /d C:\Users\rnabo\Desktop\Industrial\esp32_ota_project\flutter_app
echo ========================================
echo  ESP32 OTA Flutter Web - Debug Mode
echo  All debugPrint output will appear here
echo  Press Ctrl+C to stop
echo ========================================
echo.
C:\Flutter\flutter\bin\flutter.bat run -d chrome --web-port=8080
pause