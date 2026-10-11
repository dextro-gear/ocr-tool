@echo off
rem =============================================================================
rem  Eknathi Bhagavat OCR - PowerShell Launcher Bridge for Windows
rem =============================================================================

rem Launch PowerShell with -NoExit and ExecutionPolicy Bypass
powershell.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0start_ocr.ps1"
