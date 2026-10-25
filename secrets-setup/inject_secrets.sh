#!/usr/bin/env bash
# Carrega no Bitwarden cada modelo *.json desta pasta (cria ou atualiza o item).
# Os arquivos *.json_example não entram no laço.

# Roda a partir da pasta do script, para "../.env" e "*.json" funcionarem de qualquer lugar
cd "$(dirname "$0")" || exit 1

# tr remove o \r caso o .env tenha sido salvo com quebra de linha do Windows
set -o allexport
source <(tr -d '\r' < "../.env")
set +o allexport

bw login --apikey
BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

# Atualiza o cache local antes de procurar/editar, para não editar uma versão antiga do item
bw sync --session "$BW_SESSION"

for json_file in *.json; do
    echo "Processing: $json_file"

    # Extract item name from the "name" field of the JSON
    item_name=$(jq -r .name < "$json_file")

    # Try to get an existing item, if it exists, update, otherwise
    # create new. "bw get item <nome>" faz busca aproximada ("Pulumi Secrets"
    # casa com "GitHub Secrets"), por isso filtra pelo nome exato.
    item_id=$(bw list items --search "$item_name" --session "$BW_SESSION" \
              | jq -r --arg n "$item_name" '[.[] | select(.name == $n)][0].id // empty')
    if [ -n "$item_id" ]; then
        echo "Item '$item_name' exists, updating..."
        bw encode < "$json_file" | bw edit item "$item_id" \
                                   --session "$BW_SESSION"
    else
        echo "Item '$item_name' does not exist, creating..."
        bw encode < "$json_file" | bw create item \
                                   --session "$BW_SESSION"
    fi
done

bw sync --session "$BW_SESSION"
bw lock
