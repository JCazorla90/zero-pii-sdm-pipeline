#!/usr/bin/env python3
"""Motor SDM Zero-PII: anonimización determinista (HMAC-SHA256) y preservación de emisor."""

import hashlib
import hmac
import json
import os
import re
import sys
from pathlib import Path
import fitz  # PyMuPDF

PII_PATTERNS = {
    "IBAN": re.compile(r"\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b"),
    "DNI_NIE": re.compile(r"\b(?:[XYZ]\d{7}[A-Z]|\d{8}[A-Z])\b"),
    "EMAIL": re.compile(r"\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b"),
}


def hmac_token(value: str, salt: str, prefix: str = "PII") -> str:
    digest = hmac.new(salt.encode("utf-8"), value.encode("utf-8"), hashlib.sha256).hexdigest()[:12]
    return f"[{prefix}_{digest.upper()}]"


def mask_pdf(input_path: Path, output_path: Path, salt: str, whitelist: set[str]) -> dict:
    doc = fitz.open(input_path)
    redactions = 0

    for page in doc:
        text = page.get_text("text")
        for label, pattern in PII_PATTERNS.items():
            for match in set(pattern.findall(text)):
                if match in whitelist:
                    continue
                token = hmac_token(match, salt, label)
                for rect in page.search_for(match):
                    page.add_redact_annot(rect, text=token, fill=(0, 0, 0), text_color=(1, 1, 1))
                    redactions += 1
        page.apply_redactions()
        page.insert_text(
            fitz.Point(36, 36),
            "LAB - ZERO-PII SANITIZED",
            fontsize=10,
            color=(0.75, 0.1, 0.1),
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(output_path, garbage=4, deflate=True)
    doc.close()
    return {"file": output_path.name, "redactions": redactions, "status": "OK"}


def main() -> int:
    salt = os.environ.get("ANON_SALT", "")
    if len(salt) < 32:
        print("ERROR: ANON_SALT no configurado o longitud insuficiente.", file=sys.stderr)
        return 1

    whitelist = {x.strip() for x in os.environ.get("ISSUER_WHITELIST", "").split(",") if x.strip()}
    input_dir = Path(os.environ.get("SDM_INPUT_DIR", "/tmp/in"))
    output_dir = Path(os.environ.get("SDM_OUTPUT_DIR", "/tmp/out"))

    results = []
    for pdf_file in sorted(input_dir.rglob("*.pdf")):
        rel = pdf_file.relative_to(input_dir)
        results.append(mask_pdf(pdf_file, output_dir / rel, salt, whitelist))

    manifest_path = output_dir / "sdm_audit_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps({"status": "PASS", "files": results}, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
