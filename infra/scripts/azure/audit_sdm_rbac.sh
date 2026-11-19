#!/usr/bin/env bash
set -euo pipefail
OUT="rbac_audit_$(date -u +%Y%m%dT%H%M%SZ).csv"
echo "principal_name,role_definition,scope" > "$OUT"
az role assignment list --all --query "[].{p:principalName,r:roleDefinitionName,s:scope}" -o tsv \
  | awk -F'\t' 'BEGIN{OFS=","} {print $1,$2,$3}' >> "$OUT"
echo "Auditoría RBAC exportada a: $OUT"
