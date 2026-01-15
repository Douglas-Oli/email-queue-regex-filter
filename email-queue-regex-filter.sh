#!/bin/bash

###############################################################################
# Script genérico para filtrar e mover arquivos baseado em padrões definidos
# em um arquivo .env. Totalmente configurável e extensível.
###############################################################################

show_help() {
  cat <<EOF
Uso: $0 [opções]

Opções:
  -p, --path <dir>     Diretório onde estão os arquivos (padrão: .)
  -e, --env <arquivo>  Arquivo .env com domínios e padrões (padrão: .env)
  -d, --debug          Modo DEBUG (não move arquivos)
  -h, --help           Exibe esta ajuda

Formato sugerido do .env:
  DOMAINS="gmail.com hotmail.com"
  PATTERN_gmail_com="erro1|erro2"
  PATTERN_hotmail_com="quota exceeded"
  DEST_BASE="/srv/emailprocess-worker/nullfile"
  DEST_SUBDIR_PREFIX="null_"
EOF
  exit 0
}

# Valores padrão
SRC_DIR="."
ENV_FILE=".env"
DEBUG="false"

# Parser de argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--path) SRC_DIR="$2"; shift 2 ;;
    --path=*) SRC_DIR="${1#*=}"; shift ;;
    -e|--env) ENV_FILE="$2"; shift 2 ;;
    --env=*) ENV_FILE="${1#*=}"; shift ;;
    -d|--debug) DEBUG="true"; shift ;;
    -h|--help) show_help ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done

echo "SRC_DIR = $SRC_DIR"
echo "ENV_FILE = $ENV_FILE"
echo "DEBUG = $DEBUG"

# Carrega .env
if [ ! -f "$ENV_FILE" ]; then
  echo "Arquivo .env não encontrado: $ENV_FILE"
  exit 1
fi

set -o allexport
source "$ENV_FILE"
set +o allexport

# Diretório de destino configurável
DATE_TAG=$(date +%d-%m)
DST_DIR="${DEST_BASE}/${DEST_SUBDIR_PREFIX}${DATE_TAG}"

[ "$DEBUG" != "true" ] && mkdir -p "$DST_DIR"

# Relatório
REPORT="relatorio_debug.txt"
> "$REPORT"

echo "Domínios carregados: $DOMAINS" >> "$REPORT"

# Processamento
for DOMAIN in $DOMAINS; do

  # Converte domínio para nome de variável
  # gmail.com → PATTERN_gmail_com
  VAR_NAME="PATTERN_$(echo "$DOMAIN" | tr '[:lower:].' '[:lower:]_')"
  PATTERN="${!VAR_NAME}"

  echo "Padrão para $DOMAIN: $PATTERN" >> "$REPORT"

  # Procura arquivos *DOMAIN*.status
  for FILE in "$SRC_DIR"/*"$DOMAIN"*.status; do
    [ -e "$FILE" ] || continue

    # Verifica se contém SVRMESSAGE e algum dos padrões
    if grep -qi "SVRMESSAGE" "$FILE" && grep -Eqi "$PATTERN" "$FILE"; then

      HASH=$(basename "$FILE" | cut -d'-' -f1-3)
      RELATED="$SRC_DIR/${HASH}-${DOMAIN}"*

      if [ "$DEBUG" = "true" ]; then
        echo "DEBUG: moveria $RELATED" >> "$REPORT"
      else
        mv $RELATED "$DST_DIR"/
        echo "Movido: $RELATED" >> "$REPORT"
      fi
    fi
  done
done

[ "$DEBUG" = "true" ] && echo "Relatório gerado em: $REPORT"
