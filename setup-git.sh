#!/usr/bin/env bash
# Uso: ./setup-git.sh <url-del-repo-remoto-vacio-en-github>
# Ejemplo: ./setup-git.sh https://github.com/tu-usuario/iaw-apuntes.git
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Uso: $0 <url-del-repositorio-remoto>"
  echo "Ejemplo: $0 https://github.com/tu-usuario/iaw-apuntes.git"
  exit 1
fi

REMOTE_URL="$1"

git branch -M main

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

git push -u origin main

echo ""
echo "Repositorio subido."
echo "Activa GitHub Pages en: Settings -> Pages -> Source: GitHub Actions"
echo "El workflow .github/workflows/deploy.yml construira y publicara el sitio automaticamente en cada push a main."
