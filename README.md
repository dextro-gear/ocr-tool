# Eknathi Bhagavat OCR & Parallel Text Extractor

A specialized tool to OCR and extract parallel **Marathi (Devanagari)** and **Tamil** verses (Ovys & Sanskrit Shlokas) from the Eknathi Bhagavat literature.

---

## Quick Start

### On macOS
1. Place your PDF files into the `input/` folder (e.g. `adh-1.pdf`, `adh-2.pdf`).
2. **Double-click** `start_ocr.command` in macOS Finder.

### On Windows
1. Place your PDF files into the `input/` folder (e.g. `adh-1.pdf`, `adh-2.pdf`).
2. **Double-click** `start_ocr.bat` in Windows File Explorer.

Both scripts perform the exact same prechecks:
* Verify Python installation.
* Set up virtual environment and install dependencies (`requirements.txt`).
* Check/prompt for your **Gemini API Key** and offer to remember it in `.env`.
* Scan the `input/` folder for chapter PDFs.
* Process all chapters and export the outputs.
* Keep the window open at the end so you can inspect the results.

---

## Directory Structure

```text
ocr-tool/
├── input/                      <-- Put your chapter PDFs here (adh-1.pdf, adh-2.pdf...)
│   └── adh-1.pdf
├── output/                     <-- Generated outputs grouped by chapter
│   ├── adh-1/
│   │   ├── page_images/        <-- High-res PNG images of each rendered page
│   │   │   ├── page_001.png
│   │   │   └── ...
│   │   ├── adh-1.csv           <-- Parallel table (Page, Verse #, Marathi, Tamil)
│   │   ├── adh-1.json          <-- Structured JSON
│   │   ├── adh-1.md            <-- Formatted Markdown reading view
│   │   └── adh-1.txt           <-- Plain text
│   └── adh-2/
│       └── ...
├── extract_eknathi.py          <-- Main extraction engine
├── start_ocr.command           <-- Double-clickable launcher for macOS
├── requirements.txt            <-- Python package dependencies
└── README.md
```

---

## CLI Usage (Optional)

If running from the command line:

```bash
# 1. Activate environment
source .venv/bin/activate

# 2. Run all PDFs in the input directory
python extract_eknathi.py --input-dir input --output-dir output

# Or process a single PDF:
python extract_eknathi.py --pdf input/adh-1.pdf --output-dir output
```

### Getting a Gemini API Key
1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey).
2. Click **Create API Key**.
3. Paste it when prompted by `start_ocr.command`, or set it via:
   ```bash
   export GEMINI_API_KEY="AIzaSy..."
   ```
