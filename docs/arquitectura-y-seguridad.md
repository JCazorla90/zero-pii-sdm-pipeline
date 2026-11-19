# Arquitectura y Modelo de Seguridad (Zero-PII SDM)

## 1. Principios de diseño
* **Zero-PII en tránsito y reposo en LAB:** Toda PII detectada fuera de `ISSUER_WHITELIST` se sustituye mediante HMAC-SHA256 (`ANON_SALT`) y se valida en `verify_output_gate.py`.
* **Mínimo privilegio (OIDC):** Cero credenciales estáticas; roles segregados por función (`prod-ro`, `lab-rw`, `ecr-sign`, `iam-audit`, `release-ro`).
* **Cadena de suministro inmutable:** Verificación obligatoria de firma Cosign y *attestation* SBOM CycloneDX sobre `@sha256:...` antes de ejecutar `sdm-runner`.

## 2. Ciclo de vida de operación, rotación y auditoría

```mermaid
flowchart TB
    subgraph OP["1. Operación Continua (Manual o Cron Opcional)"]
        TRIG["Disparador<br/>Manual (siempre activo)<br/>o Cron si SDM_SCHEDULE_ENABLED = true"]
        COSIGN["Gate Previo Cosign<br/>cosign verify + verify-attestation<br/>(SBOM CycloneDX sobre @sha256)"]
        RUN["Contenedor Efímero sdm-runner<br/>mask_invoices.py + verify_output_gate.py"]
        PUB["Publicación en LAB<br/>PDFs saneados + Watermark<br/>+ sdm_audit_manifest.json"]

        TRIG --> COSIGN --> RUN --> PUB
    end

    subgraph ROT["2. Rotación Segura (Anual / Ante Incidente)"]
        SALT["Rotación ANON_SALT<br/>Nueva versión en Secrets Manager / Key Vault<br/>+ Smoke Test y refresco de LAB"]
        KMS_NEW["Rotación Clave Cosign (Zero-Downtime)<br/>1. Crear nueva clave P-256 en KMS / KV<br/>2. Re-firmar @sha256 y SBOM activo"]
        KMS_SW["3. Conmutar alias/URI vía PR firmado<br/>4. Deshabilitar clave antigua (15-30 días)"]

        KMS_NEW --> KMS_SW
    end

    subgraph AUD["3. Auditoría Mensual (ISO 27001 / ENS)"]
        SCR["Ejecución de Auditoría<br/>audit_aws_sdm_iam.sh<br/>audit_sdm_rbac.sh"]
        CSV["Evidencias Fuera de Git<br/>iam_audit_*.csv / rbac_audit_*.csv<br/>+ SBOM + Manifiestos JSON"]
        REV{"¿Desviación de<br/>mínimo privilegio?"}
        FIX["Corrección en Terraform 1.10.5<br/>vía PR firmado (main:.gitsigners)"]

        SCR --> CSV --> REV
        REV -->|Sí| FIX
        REV -->|No| OK["Cumplimiento verificado"]
    end

    PUB -.->|Alimentan evidencias| CSV
    KMS_SW -.->|Actualiza verificación| COSIGN
    SALT -.->|Nueva semilla HMAC| RUN
```
