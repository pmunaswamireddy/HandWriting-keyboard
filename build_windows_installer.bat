@echo off
echo ===================================================
echo Building Handwriting Keyboard Windows Installer
echo ===================================================

echo Step 1: Compiling Flutter Windows application in release mode...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] Flutter build failed! Make sure Visual Studio C++ workload is installed.
    exit /b %errorlevel%
)

echo.
echo Step 2: Compiling Inno Setup Installer...
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    "C:\Program Files\Inno Setup 6\ISCC.exe" installer.iss
) else (
    echo [ERROR] Inno Setup compiler (ISCC.exe) not found!
    echo Please make sure Inno Setup 6 is installed.
    exit /b 1
)

echo.
echo ===================================================
echo Success! Installer built at:
echo build\windows\installer\handwriting_keyboard_setup.exe
echo ===================================================
pause
