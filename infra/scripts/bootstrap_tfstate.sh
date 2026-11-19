#!/usr/bin/env bash
set -euo pipefail
CLOUD="${1:-}"
if [[ "$CLOUD" != "aws" && "$CLOUD" != "azure" ]]; then
  echo "Uso: $0 <aws|azure>" >&2
  exit 1
fi
echo "Bootstrap de estado remoto preparado para: $CLOUD"
