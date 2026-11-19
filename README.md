# Zero-PII Multicloud SDM Pipeline (AWS & Azure)

Pipeline de **Sensitive Data Masking (SDM)** para el saneamiento automatizado de documentos de facturación desde entornos **PROD** hacia **LAB**, diseñado bajo principios **Zero-PII**, **mínimo privilegio vía OIDC** y **trazabilidad criptográfica**.

* **Stack & Controles:** Python (`PyMuPDF`), **Terraform `1.10.5`**, GitHub Actions, Azure DevOps, **Cosign** (`ECC_NIST_P256` / Key Vault `P-256`), **SBOM CycloneDX**, **Trivy** (SARIF), **Gitleaks**, firma **SSH** (`.gitsigners`) y almacenamiento **WORM** (S3 Object Lock `COMPLIANCE` y Azure Blob Immutability).
* **Arquitectura:**
  * *Motor SDM y Quality Gate:* Anonimización determinista por **HMAC-SHA256** con *whitelist* de emisor, tachado de QR, estampado de marca de agua y emisión de manifiesto JSON de auditoría.
  * *Supply Chain & Runtime Gate:* Imágenes *multi-stage* por proveedor y verificación obligatoria de firma y *attestation* SBOM sobre `@sha256:...` antes de ejecutar el contenedor.
  * *Operación y Cumplimiento:* Control de ejecución programada mediante `SDM_SCHEDULE_ENABLED`, *runbook* de rotación *zero-downtime* (`ANON_SALT` y claves Cosign) y auditorías mensuales automatizadas de IAM/RBAC con huellas `SHA-256` archivadas en modo WORM para **ISO 27001 / ENS**.

## Documentación

* [Arquitectura y modelo de seguridad](docs/arquitectura-y-seguridad.md)
* [Guía de despliegue en AWS y Azure](docs/guia-despliegue-aws-azure.md)
* [Runbook de operación, rotación y resolución de incidencias](docs/runbook-operacion-y-respuestas.md)


## Controles principales

* **Saneamiento selectivo y Quality Gate:** Conserva los datos del emisor (`ISSUER_WHITELIST`), anonimiza PII con HMAC-SHA256 (`ANON_SALT`), tacha códigos QR y valida la salida con `scripts/verify_output_gate.py` (marca de agua + `sdm_audit_manifest.json`).
* **Cadena de suministro verificada:** Build *multi-stage* aislado por nube (`--target aws` / `--target azure`), escaneo **Trivy** (bloqueo `HIGH`/`CRITICAL` + SARIF), **SBOM CycloneDX** y firma/atestación con **Cosign** sobre el *digest* inmutable (`@sha256:...`).
* **Verificación previa a ejecución:** Antes de lanzar `docker run`, el *pipeline* valida firma criptográfica (`cosign verify`) y *attestation* SBOM (`cosign verify-attestation --type cyclonedx`) sobre el *digest* fijado.
* **Infraestructura y gobernanza:** **Terraform `1.10.5`** (`use_lockfile = true` en S3), *hooks* de `pre-commit` (`Gitleaks`, `terraform_fmt`), firma SSH de *commits* (`main:.gitsigners`) y ejecución programada opcional mediante `SDM_SCHEDULE_ENABLED` (`false` por defecto).

## Estructura del repositorio

| Ruta | Propósito |
| :--- | :--- |
| `scripts/` | Motor SDM (`mask_invoices.py`), Quality Gate (`verify_output_gate.py`) y dependencias (`requirements.txt`). |
| `tests/` | Pruebas unitarias y de integración (`test_mask_invoices.py`) con cobertura en `.coveragerc`. |
| `infra/terraform/{aws,azure}` | Módulos IaC, *backends* remotos (`backend.tf` + `backend.hcl.example`) y variables de ejemplo. |
| `infra/scripts/` | *Bootstrap* de estado (`bootstrap_tfstate.sh`), secretos, RBAC/IAM y auditorías (`audit_*`). |
| `.github/workflows/` | Validación IaC (`iac-security.yml`), *build* firmado, ejecución SDM, auditoría mensual y *releases* por *tag* firmado. |
| `azure-pipelines-*.yml` | *Pipelines* equivalentes en Azure DevOps (incluye gate SSH sobre `main:.gitsigners`). |
| `docs/` | Arquitectura, guía de despliegue paso a paso y *runbook* operativo. |

## Documentación

* [Arquitectura y modelo de seguridad](docs/arquitectura-y-seguridad.md)
* [Guía de despliegue en AWS y Azure](docs/guia-despliegue-aws-azure.md)
* [Runbook de operación, rotación y resolución de incidencias](docs/runbook-operacion-y-respuestas.md)
