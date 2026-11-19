#!/usr/bin/env python3
"""Quality Gate Zero-PII: verifica ausencia de PII residual y presencia de marca de agua."""

import json
import os
import sys
from pathlib import Path
import fitz
from mask_invoices import PII_PATTERNS


def verify_directory(output_dir: Path, whitelist: set[str]) -> bool:
    manifest = output_dir / "sdm_audit_manifest.json"
    if not manifest.exists():
        print("FAIL: Falta sdm_audit_manifest.json", file=sys.stderr)
        return False

    data = json.loads(manifest.read_text(encoding="utf-8"))
    if data.get("status") != "PASS":
        print("FAIL: Estado del manifiesto no es PASS", file=sys.stderr)
        return False

    for pdf_file in sorted(output_dir.rglob("*.pdf")):
        doc = fitz.open(pdf_file)
        full_text = "\n".join(page.get_text("text") for page in doc)
        doc.close()

        if "LAB - ZERO-PII SANITIZED" not in full_text:
            print(f"FAIL: Falta marca de agua en {pdf_file.name}", file=sys.stderr)
            return False

        for label, pattern in PII_PATTERNS.items():
            for match in pattern.findall(full_text):
                if match not in whitelist:
                    print(f"FAIL: PII residual ({label}) detectada en {pdf_file.name}", file=sys.stderr)
                    return False

    return True


def main() -> int:
    output_dir = Path(os.environ.get("SDM_OUTPUT_DIR", "/tmp/out"))
    whitelist = {x.strip() for x in os.environ.get("ISSUER_WHITELIST", "").split(",") if x.strip()}
    return 0 if verify_directory(output_dir, whitelist) else 1


if __name__ == "__main__":
    raise SystemExit(main())
