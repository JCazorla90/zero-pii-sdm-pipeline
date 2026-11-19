from pathlib import Path
import fitz
from scripts.mask_invoices import hmac_token, mask_pdf
from scripts.verify_output_gate import verify_directory


def test_hmac_deterministic():
    salt = "a" * 64
    assert hmac_token("12345678Z", salt, "DNI_NIE") == hmac_token("12345678Z", salt, "DNI_NIE")


def test_mask_and_verify_pdf(tmp_path: Path):
    in_pdf = tmp_path / "in" / "factura_01.pdf"
    out_dir = tmp_path / "out"
    out_pdf = out_dir / "factura_01.pdf"
    in_pdf.parent.mkdir(parents=True)

    doc = fitz.open()
    page = doc.new_page()
    page.insert_text(fitz.Point(72, 72), "Emisor: facturacion@miempresa.es\nCliente: 12345678Z")
    doc.save(in_pdf)
    doc.close()

    whitelist = {"facturacion@miempresa.es"}
    res = mask_pdf(in_pdf, out_pdf, "b" * 64, whitelist)
    assert res["status"] == "OK"
    assert res["redactions"] >= 1

    (out_dir / "sdm_audit_manifest.json").write_text('{"status":"PASS","files":[]}', encoding="utf-8")
    assert verify_directory(out_dir, whitelist) is True
