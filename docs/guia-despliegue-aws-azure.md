# Guía de Despliegue Multicloud (AWS & Azure)

1. **Proteger `main`:** Configurar Branch Protection / Branch Policies y Environment `PROD-Data-Read`.
2. **Desplegar IaC (Terraform 1.10.5):** Ejecutar `./infra/scripts/bootstrap_tfstate.sh <aws|azure>`, copiar `backend.hcl.example` y `terraform.tfvars.example`, y aplicar `terraform init`, `plan` y `apply`.
3. **Cargar secretos y auditar mínimo privilegio:**
   * AWS: `./infra/scripts/aws/seed_aws_sdm_secret.sh` y `./infra/scripts/aws/audit_aws_sdm_iam.sh`
   * Azure: cargar secretos en Key Vault y ejecutar `./infra/scripts/azure/audit_sdm_rbac.sh`
4. **Primer *build* firmado y Smoke Test:** Lanzar el *build* de imagen, fijar `@sha256:...` vía PR firmado y ejecutar el Smoke Test manual sobre un prefijo acotado.
