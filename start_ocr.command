#!/bin/bash
# =============================================================================
# Eknathi Bhagavat OCR - Double-Click Initialization Script (macOS)
# =============================================================================

# Move to the script's directory (ensures relative paths work in Finder)
cd "$(dirname "$0")" || exit 1

# Clear terminal screen and show banner
clear
echo "=================================================================="
echo "        Eknathi Bhagavat OCR & Parallel Text Extractor           "
echo "=================================================================="
echo ""

# -----------------------------------------------------------------------------
# 1. Precheck: Python 3
# -----------------------------------------------------------------------------
echo "[1/4] Checking Python environment..."
if ! command -v python3 &> /dev/null; then
    echo "[!] Error: python3 is not installed or not in your PATH."
    echo "    Please install Python 3 (e.g. via https://python.org or Homebrew)."
    echo ""
    read -rp "Press [Enter] to exit..."
    exit 1
fi
echo "      [✓] Python 3 detected: $(python3 --version)"

# -----------------------------------------------------------------------------
# 2. Precheck: Virtual Environment & Packages
# -----------------------------------------------------------------------------
echo "[2/4] Checking virtual environment & dependencies..."

if [ ! -d ".venv" ]; then
    echo "      Creating virtual environment (.venv)..."
    python3 -m venv .venv
fi

# Activate virtual environment
source .venv/bin/activate

# Verify required packages are installed
python3 -c "import google.genai, fitz, PIL" &> /dev/null
if [ $? -ne 0 ]; then
    echo "      Installing required packages (google-genai, pymupdf, pillow)..."
    pip install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "[!] Error installing requirements. Check your internet connection."
        read -rp "Press [Enter] to exit..."
        exit 1
    fi
fi
echo "      [✓] All required packages are ready."

# -----------------------------------------------------------------------------
# 3. Precheck: Gemini API Key
# -----------------------------------------------------------------------------
echo "[3/4] Checking Gemini API Key..."

# Load from .env if present
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -n "$GEMINI_API_KEY" ]; then
    # Mask API key for display
    KEY_LEN=${#GEMINI_API_KEY}
    if [ $KEY_LEN -gt 8 ]; then
        MASKED="${GEMINI_API_KEY:0:6}...${GEMINI_API_KEY: -4}"
    else
        MASKED="********"
    fi
    echo "      [✓] Found existing Gemini API Key ($MASKED)."
    echo ""
    read -rp "      Press [Enter] to use this key, or type a new key: " USER_KEY
    if [ -n "$USER_KEY" ]; then
        GEMINI_API_KEY="$USER_KEY"
        export GEMINI_API_KEY
        read -rp "      Save this new key to .env for future runs? (y/n) [default: y]: " SAVE_ENV
        SAVE_ENV=${SAVE_ENV:-y}
        if [[ "$SAVE_ENV" =~ ^[Yy]$ ]]; then
            echo "GEMINI_API_KEY=\"$GEMINI_API_KEY\"" > .env
            echo "      [✓] Saved to .env"
        fi
    fi
else
    echo "      [!] No GEMINI_API_KEY detected in environment or .env."
    echo ""
    while [ -z "$GEMINI_API_KEY" ]; do
        echo "      Get your free API key at: https://aistudio.google.com/app/apikey"
        read -rp "      Please paste your Gemini API Key: " USER_KEY
        USER_KEY=$(echo "$USER_KEY" | xargs)
        if [ -n "$USER_KEY" ]; then
            GEMINI_API_KEY="$USER_KEY"
            export GEMINI_API_KEY
            echo ""
            read -rp "      Save this key to .env for future automatic runs? (y/n) [default: y]: " SAVE_ENV
            SAVE_ENV=${SAVE_ENV:-y}
            if [[ "$SAVE_ENV" =~ ^[Yy]$ ]]; then
                echo "GEMINI_API_KEY=\"$GEMINI_API_KEY\"" > .env
                echo "      [✓] Saved to .env"
            fi
        else
            echo "      [!] Key cannot be empty. Please try again."
        fi
    done
fi

# -----------------------------------------------------------------------------
# 4. Precheck: Input Folder & PDFs
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] Checking 'input' folder..."
mkdir -p input

while true; do
    PDF_COUNT=$(find input -maxdepth 1 -name "*.pdf" -o -name "*.PDF" 2>/dev/null | wc -l | xargs)
    if [ "$PDF_COUNT" -gt 0 ]; then
        echo "      [✓] Found $PDF_COUNT PDF file(s) in 'input/' folder:"
        for f in input/*.pdf input/*.PDF; do
            [ -e "$f" ] && echo "          - $(basename "$f")"
        done
        break
    else
        echo ""
        echo "      ========================================================"
        echo "      [!] No PDF files found in 'input/' folder!"
        echo "      ========================================================"
        echo "      Please copy your chapter files (e.g. adh-1.pdf, adh-2.pdf)"
        echo "      into the following directory:"
        echo "      $(pwd)/input"
        echo ""
        read -rp "      Once files are copied, press [Enter] to re-check (or 'q' to quit): " CHOICE
        if [[ "$CHOICE" =~ ^[Qq]$ ]]; then
            echo "Exiting."
            exit 0
        fi
    fi
done

# -----------------------------------------------------------------------------
# 5. Launch Extraction
# -----------------------------------------------------------------------------
echo ""
echo "=================================================================="
echo " Starting OCR & Parallel Text Extraction..."
echo "=================================================================="

python3 extract_eknathi.py --input-dir input --output-dir output

EXIT_CODE=$?

echo ""
echo "=================================================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo " [✓] Extraction completed successfully!"
    echo " All output folders are available at:"
    echo " $(pwd)/output/"
else
    echo " [!] Processing encountered an issue (Exit Code: $EXIT_CODE)."
fi
echo "=================================================================="
echo ""
read -rp "Press [Enter] to close this window..."
