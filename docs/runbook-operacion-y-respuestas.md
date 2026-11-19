# Runbook de Operación, Rotación y Respuesta a Incidencias

## 1. Control de ejecución programada opcional (`SDM_SCHEDULE_ENABLED`)
La ejecución nocturna (`cron`) está desactivada por defecto (`false`).
* **GitHub Actions:** `gh variable set SDM_SCHEDULE_ENABLED --body "true"` (o `"false"` para pausar).
* **Azure DevOps:** Modificar `SDM_SCHEDULE_ENABLED` en **Pipelines - Edit - Variables**.

## 2. Rotación de `ANON_SALT` y clave Cosign (Zero-Downtime)
* **`ANON_SALT`:** Rotar anualmente coincidiendo con refresco de LAB; generar nueva versión en Secrets Manager / Key Vault y validar con Smoke Test.
* **Clave Cosign:** Crear nueva clave `P-256`, re-firmar el `@sha256:...` y el SBOM activo antes de conmutar alias/URI, y deshabilitar la clave antigua tras 15–30 días de gracia.
