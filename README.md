# Zero-PII SDM Pipeline (AWS & Azure)

Pipeline multicloud de **Sensitive Data Masking (SDM)** para sanear documentación de facturación desde **PROD** hacia **LAB** bajo un enfoque **Zero-PII**, **mínimo privilegio (OIDC)** y **trazabilidad criptográfica extremo a extremo**.

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
