# Changelog

Todos los cambios relevantes de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado sigue [Semantic Versioning](https://semver.org/lang/es/).

## [1.0.0] - 2026-11-19

### Added

#### Motor SDM y Quality Gate (Zero-PII)
* Motor de saneamiento selectivo (`scripts/mask_invoices.py`) con preservación de datos del emisor (`ISSUER_WHITELIST`), anonimización determinista mediante **HMAC-SHA256** (`ANON_SALT`) y tachado de códigos QR.
* *Quality Gate* automatizado (`scripts/verify_output_gate.py`) con aplicación de marca de agua, validación de ausencia de PII residual y generación de `sdm_audit_manifest.json`.
* Suite de pruebas unitarias e integración (`tests/test_mask_invoices.py`) con umbrales de cobertura definidos en `.coveragerc`.

#### Cadena de Suministro y Contenedores
* `Dockerfile` *multi-stage* aislado por proveedor (`--target aws` y `--target azure`) con usuario sin privilegios.
* *Pipelines* de *build* firmado en GitHub Actions y Azure DevOps con escaneo **Trivy** (bloqueo en vulnerabilidades `HIGH`/`CRITICAL` + reporte **SARIF**), generación de **SBOM CycloneDX** y firma/atestación criptográfica con **Cosign** (AWS KMS `ECC_NIST_P256` / Azure Key Vault `P-256`).
* Gate previo a la ejecución en los *pipelines* SDM (`cosign verify` + `cosign verify-attestation --type cyclonedx`) sobre el *digest* inmutable (`@sha256:...`).

#### Infraestructura como Código (Terraform 1.10.5)
* Módulos IaC para **AWS** (S3 endurecido, KMS, Secrets Manager, ECR inmutable, proveedor OIDC de GitHub y roles IAM de mínimo privilegio) y **Azure** (Storage Accounts, Key Vault, ACR sin usuario Admin y asignaciones RBAC).
* *Bootstrap* de estado remoto (`infra/scripts/bootstrap_tfstate.sh`) con bloqueo nativo (`use_lockfile = true` en S3) y plantillas `backend.hcl.example` / `terraform.tfvars.example`.
* Almacenamiento inmutable **WORM** para evidencias de cumplimiento: bucket **S3 Object Lock** en modo `COMPLIANCE` (365 días) y contenedor **Azure Blob Storage** con *Time-based Immutability Policy* (365 días).

#### Gobernanza, Cumplimiento y Operación (ISO 27001 / ENS)
* *Hooks* de `pre-commit` (`Gitleaks`, `terraform_fmt`), firma criptográfica de *commits* y *tags* mediante claves SSH Ed25519 y verificación en Azure DevOps contra `origin/main:.gitsigners`.
* *Workflows* de auditoría mensual automatizada (`monthly-iam-audit-aws.yml` y `azure-pipelines-monthly-rbac-audit.yml`) con generación de informes CSV, huellas `SHA256SUMS.txt` y archivado automático en almacenamiento WORM.
* Control opcional de ejecución programada (`cron`) mediante la variable `SDM_SCHEDULE_ENABLED` (`false` por defecto) para activar o pausar ejecuciones periódicas sin modificar código.
* Documentación completa en `README.md` y `docs/`: arquitectura y diagramas Mermaid (`arquitectura-y-seguridad.md`), guía de despliegue multicloud (`guia-despliegue-aws-azure.md`) y *runbook* operativo con procedimiento de rotación *zero-downtime* (`runbook-operacion-y-respuestas.md`).
