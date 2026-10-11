# =============================================================================
# Eknathi Bhagavat OCR - PowerShell Launcher (Windows)
# =============================================================================

# Ensure execution starts in the script's directory
Set-Location -Path $PSScriptRoot

Clear-Host
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "        Eknathi Bhagavat OCR & Parallel Text Extractor           " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# 1. Precheck: Python Environment
# -----------------------------------------------------------------------------
Write-Host "[1/4] Checking Python environment..." -ForegroundColor Yellow

$PythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $PythonCmd = "python"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonCmd = "py"
}

if (-not $PythonCmd) {
    Write-Host "[!] Error: Python was not found in your system PATH." -ForegroundColor Red
    Write-Host "    Please install Python from https://www.python.org/" -ForegroundColor Red
    Write-Host "    Make sure to check 'Add Python to PATH' during setup." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press [Enter] to exit..."
    exit 1
}

$PyVersion = & $PythonCmd --version 2>&1
Write-Host "      [✓] Python detected: $PyVersion" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 2. Precheck: Virtual Environment & Dependencies
# -----------------------------------------------------------------------------
Write-Host "[2/4] Checking virtual environment & dependencies..." -ForegroundColor Yellow

$VenvDir = Join-Path $PSScriptRoot ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvPip = Join-Path $VenvDir "Scripts\pip.exe"

if (-not (Test-Path $VenvPython)) {
    Write-Host "      Creating virtual environment (.venv)..." -ForegroundColor Gray
    & $PythonCmd -m venv .venv
    if (-not (Test-Path $VenvPython)) {
        Write-Host "[!] Error creating virtual environment." -ForegroundColor Red
        Read-Host "Press [Enter] to exit..."
        exit 1
    }
}

# Verify required packages inside the virtual environment
& $VenvPython -c "import google.genai, fitz, PIL" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Installing required packages (google-genai, pymupdf, pillow)..." -ForegroundColor Gray
    & $VenvPip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Failed to install dependencies. Check your internet connection." -ForegroundColor Red
        Read-Host "Press [Enter] to exit..."
        exit 1
    }
}
Write-Host "      [✓] All required packages are ready." -ForegroundColor Green

# -----------------------------------------------------------------------------
# 3. Precheck: Gemini API Key
# -----------------------------------------------------------------------------
Write-Host "[3/4] Checking Gemini API Key..." -ForegroundColor Yellow

$EnvFile = Join-Path $PSScriptRoot ".env"

# Load from .env if present
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim().Trim("`"'")
            if ($k -eq "GEMINI_API_KEY" -and -not $env:GEMINI_API_KEY) {
                $env:GEMINI_API_KEY = $v
            }
        }
    }
}

if ($env:GEMINI_API_KEY) {
    $KeyLen = $env:GEMINI_API_KEY.Length
    $Masked = if ($KeyLen -gt 8) {
        $env:GEMINI_API_KEY.Substring(0, 6) + "..." + $env:GEMINI_API_KEY.Substring($KeyLen - 4)
    } else {
        "********"
    }
    Write-Host "      [✓] Found existing Gemini API Key ($Masked)." -ForegroundColor Green
    Write-Host ""
    $UserKey = Read-Host "      Press [Enter] to use this key, or type a new key"
    if ($UserKey.Trim()) {
        $env:GEMINI_API_KEY = $UserKey.Trim()
        $SaveChoice = Read-Host "      Save this new key to .env for future runs? (y/n) [default: y]"
        if (-not $SaveChoice -or $SaveChoice -match "^[Yy]") {
            Set-Content -Path $EnvFile -Value "GEMINI_API_KEY=`"$($env:GEMINI_API_KEY)`"" -Encoding UTF8
            Write-Host "      [✓] Saved to .env" -ForegroundColor Green
        }
    }
} else {
    Write-Host "      [!] No GEMINI_API_KEY detected in environment or .env." -ForegroundColor Yellow
    Write-Host ""
    while (-not $env:GEMINI_API_KEY) {
        Write-Host "      Get your free API key at: https://aistudio.google.com/app/apikey" -ForegroundColor Cyan
        $InputKey = Read-Host "      Please paste your Gemini API Key"
        if ($InputKey.Trim()) {
            $env:GEMINI_API_KEY = $InputKey.Trim()
            Write-Host ""
            $SaveChoice = Read-Host "      Save this key to .env for future runs? (y/n) [default: y]"
            if (-not $SaveChoice -or $SaveChoice -match "^[Yy]") {
                Set-Content -Path $EnvFile -Value "GEMINI_API_KEY=`"$($env:GEMINI_API_KEY)`"" -Encoding UTF8
                Write-Host "      [✓] Saved to .env" -ForegroundColor Green
            }
        } else {
            Write-Host "      [!] Key cannot be empty. Please try again." -ForegroundColor Red
        }
    }
}

# -----------------------------------------------------------------------------
# 4. Precheck: Input Folder & PDFs
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Checking 'input' folder..." -ForegroundColor Yellow

$InputDir = Join-Path $PSScriptRoot "input"
if (-not (Test-Path $InputDir)) {
    New-Item -ItemType Directory -Path $InputDir | Out-Null
}

while ($true) {
    $PdfFiles = Get-ChildItem -Path $InputDir -Filter "*.pdf" -File
    if ($PdfFiles.Count -gt 0) {
        Write-Host "      [✓] Found $($PdfFiles.Count) PDF file(s) in 'input\':" -ForegroundColor Green
        foreach ($pdf in $PdfFiles) {
            Write-Host "          - $($pdf.Name)" -ForegroundColor Gray
        }
        break
    } else {
        Write-Host ""
        Write-Host "      ========================================================" -ForegroundColor Yellow
        Write-Host "      [!] No PDF files found in 'input' folder!" -ForegroundColor Yellow
        Write-Host "      ========================================================" -ForegroundColor Yellow
        Write-Host "      Please copy your chapter files (e.g. adh-1.pdf, adh-2.pdf)" -ForegroundColor Gray
        Write-Host "      into the following directory:" -ForegroundColor Gray
        Write-Host "      $InputDir" -ForegroundColor Cyan
        Write-Host ""
        $Choice = Read-Host "      Once copied, press [Enter] to scan again (or type 'q' to quit)"
        if ($Choice -match "^[Qq]") {
            Write-Host "Exiting."
            exit 0
        }
    }
}

# -----------------------------------------------------------------------------
# 5. Launch Extraction
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " Starting OCR & Parallel Text Extraction..." -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

& $VenvPython extract_eknathi.py --input-dir input --output-dir output

$RunExit = $LASTEXITCODE

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
if ($RunExit -eq 0) {
    Write-Host " [✓] Extraction completed successfully!" -ForegroundColor Green
    Write-Host " All output folders are located in:" -ForegroundColor Gray
    Write-Host " $(Join-Path $PSScriptRoot 'output')" -ForegroundColor Cyan
} else {
    Write-Host " [!] Processing encountered an issue (Exit Code: $RunExit)." -ForegroundColor Red
}
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# Keep window open even after completion
Write-Host "Processing is complete. This PowerShell window will remain open." -ForegroundColor Gray
Read-Host "Press [Enter] to close this window..."
