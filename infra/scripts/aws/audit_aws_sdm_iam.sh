#!/usr/bin/env bash
set -euo pipefail
OUT="iam_audit_$(date -u +%Y%m%dT%H%M%SZ).csv"
echo "role_name,policy_type,policy_name" > "$OUT"
for ROLE in role-gh-sdm-prod-ro role-gh-sdm-lab-rw role-gh-sdm-ecr-sign role-gh-sdm-release-ro; do
  aws iam list-role-policies --role-name "$ROLE" --query 'PolicyNames[]' --output text 2>/dev/null | tr '\t' '\n' | while read -r pol; do
    [[ -n "$pol" ]] && echo "${ROLE},inline,${pol}" >> "$OUT"
  done
  aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyName' --output text 2>/dev/null | tr '\t' '\n' | while read -r pol; do
    [[ -n "$pol" ]] && echo "${ROLE},managed,${pol}" >> "$OUT"
  done
done
echo "Auditoría IAM exportada a: $OUT"
