#!/usr/bin/env python3
"""
Eknathi Bhagavat Literature OCR & Text Extractor
================================================
Extracts Marathi (Devanagari) and Tamil (Tamil script) Ovys and Sanskrit Shlokas
from dual-language PDF pages into clean, editable Unicode text.

Features:
- Processes single PDFs or entire batch directories (e.g. input/adh-1.pdf, input/adh-2.pdf).
- Auto-creates chapter-specific output folders (e.g. output/adh-1/, output/adh-2/).
- Saves high-res page images into output/<chapter>/page_images/.
- Outputs aligned Unicode text in JSON, CSV, Markdown, and TXT formats.
- Supports Gemini Vision API (recommended) and local Tesseract OCR.
"""

import os
import re
import sys
import json
import csv
import argparse
from pathlib import Path
from typing import List, Dict, Any, Optional

def load_env_file():
    """Reads .env file in the current or script directory if it exists."""
    for base in [Path.cwd(), Path(__file__).parent]:
        env_path = base / ".env"
        if env_path.exists():
            try:
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            k = k.strip()
                            v = v.strip().strip("'\"")
                            if k not in os.environ:
                                os.environ[k] = v
            except Exception:
                pass

def extract_with_gemini(image_path: str, api_key: str, model_name: str = "gemini-2.0-flash") -> Dict[str, Any]:
    """
    Uses Gemini Vision API to extract Devanagari Marathi and Tamil Ovys.
    """
    try:
        from google import genai
        from google.genai import types
        from PIL import Image
    except ImportError:
        raise ImportError("Please install `google-genai` and `pillow`: pip install google-genai pillow")

    client = genai.Client(api_key=api_key)
    img = Image.open(image_path)

    prompt = """You are an expert Indic epigraphist and OCR transcriber specializing in Marathi and Tamil devotional literature (Eknathi Bhagavat).

This page contains:
1. Top section: Eknathi Bhagavat Ovys in Marathi (Devanagari script) and any Sanskrit Shlokas.
2. Bottom section: The corresponding parallel text in Tamil script (phonetic transliteration of the Ovys).

Task:
Extract all verses and invocations accurately into clean Unicode text.
Return a valid JSON object with the following schema:
{
  "chapter": "अध्याय - 1",
  "invocations": {
    "marathi": "|| श्रीः || ...",
    "tamil": "|| ஸ்ரீ: || ..."
  },
  "verses": [
    {
      "verse_number": 1,
      "type": "ovy",
      "marathi": "ॐ नमो जी जनार्दना । नाहीँ भवअभवभावना । न देखोनि मीतूंByteणा । नमन श्रीचरणा सद्गुरूराया ॥",
      "tamil": "ஓம் நமோ ஜீ ஜனார்தனா | நாஹீ பவஅபவபாவனா | ந தேகோனி மீதூம்பணா | நமன ஸ்ரீசரணா ஸத்குரூராயா ||"
    }
  ]
}

Formatting rules:
- Ensure exact Unicode characters for Marathi (Devanagari) and Tamil.
- Preserve verse numbering (1, 2, 3...).
- Keep the traditional line endings with danda (|) and double danda (||).
- Do not add conversational text; return only pure valid JSON.
"""

    response = client.models.generate_content(
        model=model_name,
        contents=[img, prompt],
        config=types.GenerateContentConfig(
            response_mime_type="application/json"
        )
    )

    try:
        return json.loads(response.text)
    except Exception:
        clean_json = re.sub(r"^```json\s*|\s*```$", "", response.text.strip(), flags=re.MULTILINE)
        return json.loads(clean_json)


def extract_with_tesseract(page_image_path: str, marathi_lang: str = "mar", tamil_lang: str = "tam") -> Dict[str, Any]:
    """
    Local offline extraction using Tesseract OCR with dual-half image splitting.
    """
    try:
        import pytesseract
        from PIL import Image
    except ImportError:
        raise ImportError("Please install `pytesseract` and `pillow`: pip install pytesseract pillow")

    img = Image.open(page_image_path)
    width, height = img.size

    top_half = img.crop((0, 0, width, int(height * 0.48)))
    bottom_half = img.crop((0, int(height * 0.48), width, height))

    marathi_raw = pytesseract.image_to_string(top_half, lang=marathi_lang)
    tamil_raw = pytesseract.image_to_string(bottom_half, lang=tamil_lang)

    verses = align_verses(marathi_raw, tamil_raw)

    return {
        "marathi_raw": marathi_raw,
        "tamil_raw": tamil_raw,
        "verses": verses
    }


def align_verses(marathi_text: str, tamil_text: str) -> List[Dict[str, Any]]:
    """
    Aligns Marathi and Tamil verses by verse numbers.
    """
    def parse_numbered_blocks(text: str) -> Dict[int, str]:
        chunks = re.split(r'(?:^|\s)(\d+)[\.\)]\s+', text)
        result = {}
        if len(chunks) > 1:
            for i in range(1, len(chunks), 2):
                num = int(chunks[i])
                content = chunks[i+1].strip()
                result[num] = content
        return result

    m_dict = parse_numbered_blocks(marathi_text)
    t_dict = parse_numbered_blocks(tamil_text)

    all_nums = sorted(set(list(m_dict.keys()) + list(t_dict.keys())))
    aligned = []
    for num in all_nums:
        aligned.append({
            "verse_number": num,
            "marathi": m_dict.get(num, ""),
            "tamil": t_dict.get(num, "")
        })
    return aligned


def save_chapter_outputs(all_pages_data: List[Dict[str, Any]], chapter_dir: Path, chapter_name: str):
    """
    Exports extracted data to JSON, CSV, Markdown, and TXT inside the chapter directory.
    """
    chapter_dir.mkdir(parents=True, exist_ok=True)

    # 1. JSON Export
    json_path = chapter_dir / f"{chapter_name}.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(all_pages_data, f, ensure_ascii=False, indent=2)

    # Flatten all verses across pages
    flattened_verses = []
    for page_idx, page in enumerate(all_pages_data, 1):
        page_num = page.get("page_number", page_idx)
        for verse in page.get("verses", []):
            flattened_verses.append({
                "Page": page_num,
                "Verse_Number": verse.get("verse_number"),
                "Type": verse.get("type", "ovy"),
                "Marathi_Devanagari": verse.get("marathi", "").strip(),
                "Tamil_Script": verse.get("tamil", "").strip(),
            })

    # 2. CSV Export
    csv_path = chapter_dir / f"{chapter_name}.csv"
    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Page", "Verse_Number", "Type", "Marathi_Devanagari", "Tamil_Script"])
        writer.writeheader()
        writer.writerows(flattened_verses)

    # 3. Markdown Export
    md_path = chapter_dir / f"{chapter_name}.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(f"# श्री एकनाथी भागवत - {chapter_name}\n\n")
        f.write("> Extracted Marathi (Devanagari) & Tamil parallel literature\n\n")

        current_page = None
        for v in flattened_verses:
            if v["Page"] != current_page:
                current_page = v["Page"]
                f.write(f"\n---\n## पृष्ठ {current_page} (Page {current_page})\n\n")

            v_num = v["Verse_Number"]
            m_text = v["Marathi_Devanagari"]
            t_text = v["Tamil_Script"]

            f.write(f"### ओवी {v_num}\n")
            f.write(f"**मराठी:**\n> {m_text}\n\n")
            f.write(f"**தமிழ்:**\n> {t_text}\n\n")

    # 4. Text Export
    txt_path = chapter_dir / f"{chapter_name}.txt"
    with open(txt_path, "w", encoding="utf-8") as f:
        for v in flattened_verses:
            f.write(f"[{v['Verse_Number']}]\n")
            f.write(f"MARATHI: {v['Marathi_Devanagari']}\n")
            f.write(f"TAMIL:   {v['Tamil_Script']}\n\n")

    print(f"\n[✓] Outputs successfully saved in {chapter_dir}:")
    print(f"    - JSON:     {json_path.name}")
    print(f"    - CSV:      {csv_path.name}")
    print(f"    - Markdown: {md_path.name}")
    print(f"    - Text:     {txt_path.name}")


def convert_pdf_to_images(pdf_path: str, output_dir: Path, dpi: int = 200) -> List[str]:
    """
    Renders PDF pages to high-resolution PNG images.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    image_paths = []

    try:
        import fitz  # PyMuPDF
        doc = fitz.open(pdf_path)
        for i, page in enumerate(doc):
            pix = page.get_pixmap(dpi=dpi)
            out_img = output_dir / f"page_{i+1:03d}.png"
            pix.save(str(out_img))
            image_paths.append(str(out_img))
        doc.close()
        return image_paths
    except ImportError:
        pass

    try:
        from pdf2image import convert_from_path
        images = convert_from_path(pdf_path, dpi=dpi)
        for i, img in enumerate(images):
            out_img = output_dir / f"page_{i+1:03d}.png"
            img.save(str(out_img), "PNG")
            image_paths.append(str(out_img))
        return image_paths
    except ImportError:
        raise ImportError("Please install either `pymupdf` or `pdf2image` to convert PDF to images: pip install pymupdf")


def process_single_pdf(pdf_path: Path, output_root: Path, backend: str, api_key: Optional[str],
                       start_page: int, end_page: Optional[int], model_name: str = "gemini-2.0-flash"):
    """
    Processes one PDF file and saves all images and texts inside output_root / <chapter_name>.
    """
    chapter_name = pdf_path.stem
    chapter_dir = output_root / chapter_name
    img_dir = chapter_dir / "page_images"

    print("\n" + "=" * 60)
    print(f"[*] Processing Chapter: {chapter_name} ({pdf_path.name})")
    print(f"    Target directory: {chapter_dir}")
    print("=" * 60)

    print(f"[*] Rendering PDF pages to: {img_dir} ...")
    page_images = convert_pdf_to_images(str(pdf_path), img_dir)
    print(f"[✓] Rendered {len(page_images)} page images.")

    start = max(1, start_page)
    end = min(len(page_images), end_page) if end_page else len(page_images)

    selected_images = page_images[start-1:end]
    all_pages_data = []

    for idx, img_path in enumerate(selected_images, start=start):
        print(f"[*] Extracting page {idx}/{end} with backend '{backend}'...")
        if backend == "gemini":
            if not api_key:
                print("Error: GEMINI_API_KEY environment variable or --api-key argument is required for gemini backend.")
                sys.exit(1)
            page_data = extract_with_gemini(img_path, api_key=api_key, model_name=model_name)
            page_data["page_number"] = idx
            all_pages_data.append(page_data)
        else:
            page_data = extract_with_tesseract(img_path)
            page_data["page_number"] = idx
            all_pages_data.append(page_data)

    save_chapter_outputs(all_pages_data, chapter_dir, chapter_name)


def main():
    load_env_file()

    parser = argparse.ArgumentParser(description="Extract Marathi and Tamil Ovys from Eknathi Bhagavat PDFs.")
    parser.add_argument("--pdf", type=str, default=None, help="Path to a single input PDF file")
    parser.add_argument("--input-dir", type=str, default="input", help="Directory containing PDF files (default: 'input')")
    parser.add_argument("--backend", choices=["gemini", "tesseract"], default="gemini", help="OCR Backend to use")
    parser.add_argument("--api-key", type=str, default=os.getenv("GEMINI_API_KEY"), help="Google Gemini API Key")
    parser.add_argument("--model", type=str, default="gemini-2.0-flash", help="Gemini model name")
    parser.add_argument("--output-dir", type=str, default="output", help="Root output directory (default: 'output')")
    parser.add_argument("--start-page", type=int, default=1, help="First page to process")
    parser.add_argument("--end-page", type=int, default=None, help="Last page to process")

    args = parser.parse_args()

    api_key = args.api_key or os.getenv("GEMINI_API_KEY")
    if args.backend == "gemini" and not api_key:
        print("[!] Error: GEMINI_API_KEY not found in environment or arguments.")
        sys.exit(1)

    output_root = Path(args.output_dir)

    if args.pdf:
        pdf_file = Path(args.pdf)
        if not pdf_file.exists():
            print(f"[!] Error: File '{args.pdf}' not found.")
            sys.exit(1)
        process_single_pdf(pdf_file, output_root, args.backend, api_key, args.start_page, args.end_page, args.model)
    else:
        input_dir = Path(args.input_dir)
        if not input_dir.exists():
            print(f"[!] Input directory '{args.input_dir}' does not exist.")
            sys.exit(1)

        pdf_files = sorted(list(input_dir.glob("*.pdf")) + list(input_dir.glob("*.PDF")))
        if not pdf_files:
            print(f"[!] No PDF files found in '{args.input_dir}'.")
            sys.exit(1)

        print(f"[*] Found {len(pdf_files)} PDF file(s) in '{args.input_dir}':")
        for p in pdf_files:
            print(f"    - {p.name}")

        for pdf_file in pdf_files:
            process_single_pdf(pdf_file, output_root, args.backend, api_key, args.start_page, args.end_page, args.model)

    print("\n" + "=" * 60)
    print("[✓] All processing finished successfully!")
    print("=" * 60)

if __name__ == "__main__":
    main()
