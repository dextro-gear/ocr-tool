@echo off
rem =============================================================================
rem  Eknathi Bhagavat OCR - Double-Click Initialization Script (Windows)
rem =============================================================================

setlocal enabledelayedexpansion
title Eknathi Bhagavat OCR & Parallel Text Extractor

cls
echo ==================================================================
echo         Eknathi Bhagavat OCR ^& Parallel Text Extractor           
echo ==================================================================
echo.

rem Move to script directory
cd /d "%~dp0"

rem -----------------------------------------------------------------------------
rem 1. Precheck: Python
rem -----------------------------------------------------------------------------
echo [1/4] Checking Python environment...
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    where py >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [!] Error: Python is not found in your PATH.
        echo     Please install Python from https://www.python.org/
        echo     Make sure to check "Add Python to PATH" during installation.
        echo.
        pause
        exit /b 1
    ) else (
        set "PY_CMD=py"
    )
) else (
    set "PY_CMD=python"
)

for /f "tokens=*" %%v in ('%PY_CMD% --version 2^>^&1') do set "PY_VER=%%v"
echo       [+] Python detected: !PY_VER!

rem -----------------------------------------------------------------------------
rem 2. Precheck: Virtual Environment & Dependencies
rem -----------------------------------------------------------------------------
echo [2/4] Checking virtual environment ^& dependencies...

if not exist ".venv" (
    echo       Creating virtual environment (.venv)...
    %PY_CMD% -m venv .venv
)

rem Activate virtual environment
if exist ".venv\Scripts\activate.bat" (
    call .venv\Scripts\activate.bat
) else (
    echo [!] Could not locate .venv\Scripts\activate.bat
    pause
    exit /b 1
)

rem Verify required packages
python -c "import google.genai, fitz, PIL" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo       Installing required packages from requirements.txt...
    pip install -r requirements.txt
    if %ERRORLEVEL% neq 0 (
        echo [!] Failed to install dependencies. Please check your internet connection.
        pause
        exit /b 1
    )
)
echo       [+] All required packages are ready.

rem -----------------------------------------------------------------------------
rem 3. Precheck: Gemini API Key
rem -----------------------------------------------------------------------------
echo [3/4] Checking Gemini API Key...

rem Load from .env if present
if exist ".env" (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "KEY_NAME=%%A"
        set "KEY_VAL=%%B"
        rem Strip quotes and spaces
        set "KEY_VAL=!KEY_VAL:"=!"
        if "!KEY_NAME!"=="GEMINI_API_KEY" (
            set "GEMINI_API_KEY=!KEY_VAL!"
        )
    )
)

if defined GEMINI_API_KEY (
    echo       [+] Found existing Gemini API Key.
    echo.
    set /p "USER_KEY=      Press [Enter] to use this key, or type a new key: "
    if defined USER_KEY (
        set "GEMINI_API_KEY=!USER_KEY!"
        set /p "SAVE_ENV=      Save this new key to .env for future runs? (y/n) [default: y]: "
        if not defined SAVE_ENV set "SAVE_ENV=y"
        if /i "!SAVE_ENV!"=="y" (
            echo GEMINI_API_KEY="!GEMINI_API_KEY!" > .env
            echo       [+] Saved to .env
        )
    )
) else (
    echo       [!] No GEMINI_API_KEY detected in environment or .env.
    echo.
    :ask_key
    echo       Get your free API key at: https://aistudio.google.com/app/apikey
    set /p "USER_KEY=      Please paste your Gemini API Key: "
    if not defined USER_KEY (
        echo       [!] Key cannot be empty. Please try again.
        goto ask_key
    )
    set "GEMINI_API_KEY=!USER_KEY!"
    echo.
    set /p "SAVE_ENV=      Save this key to .env for future runs? (y/n) [default: y]: "
    if not defined SAVE_ENV set "SAVE_ENV=y"
    if /i "!SAVE_ENV!"=="y" (
        echo GEMINI_API_KEY="!GEMINI_API_KEY!" > .env
        echo       [+] Saved to .env
    )
)

rem -----------------------------------------------------------------------------
rem 4. Precheck: Input Folder & PDFs
rem -----------------------------------------------------------------------------
echo.
echo [4/4] Checking 'input' folder...
if not exist "input" mkdir "input"

:check_input
set "PDF_FOUND=0"
for %%F in (input\*.pdf input\*.PDF) do (
    set "PDF_FOUND=1"
)

if "!PDF_FOUND!"=="0" (
    echo.
    echo       ========================================================
    echo       [!] No PDF files found in 'input' folder!
    echo       ========================================================
    echo       Please copy your chapter files (e.g. adh-1.pdf, adh-2.pdf)
    echo       into the following folder:
    echo       %CD%\input
    echo.
    set /p "RECHECK=      Once copied, press [Enter] to scan again (or type 'q' to quit): "
    if /i "!RECHECK!"=="q" exit /b 0
    goto check_input
) else (
    echo       [+] Found PDF files in 'input\':
    for %%F in (input\*.pdf input\*.PDF) do (
        echo           - %%~nxF
    )
)

rem -----------------------------------------------------------------------------
rem 5. Launch Extraction
rem -----------------------------------------------------------------------------
echo.
echo ==================================================================
echo  Starting OCR ^& Parallel Text Extraction...
echo ==================================================================

python extract_eknathi.py --input-dir input --output-dir output

set "RUN_EXIT=!ERRORLEVEL!"

echo.
echo ==================================================================
if "!RUN_EXIT!"=="0" (
    echo  [+] Extraction completed successfully!
    echo  All chapter output folders are located in:
    echo  %CD%\output\
) else (
    echo  [!] Processing encountered an issue (Exit Code: !RUN_EXIT!).
)
echo ==================================================================
echo.
pause
