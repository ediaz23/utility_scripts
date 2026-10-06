#!/bin/bash

set -e

if [[ -z "$1" ]]; then
    echo "Uso: run_odoo <version> [parametros extra para odoo]"
    echo "Ejemplo: run_odoo 19 -u base --i18n-overwrite"
    exit 1
fi

version="$1"
shift

name="acrux_chat${version}"
compose="$HOME/trabajo/Docker-composes/${name}.yml"

# Si pasan -d/--database entre los extras, esa es la DB y la sacamos de los args.
db="$name"
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--database)
            db="$2"
            shift 2
            ;;
        -d=*|--database=*)
            db="${1#*=}"
            shift
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

if [[ ! -f "$compose" ]]; then
    echo "No existe el compose: $compose"
    exit 1
fi

# Si quedo un contenedor viejo con ese nombre, --name falla. Lo limpiamos.
if docker container inspect "$name" >/dev/null 2>&1; then
    echo "Eliminando contenedor previo: $name"
    docker rm -f "$name" >/dev/null
fi

docker compose -f "$compose" run --service-ports --name "$name" --rm odoo \
    --limit-time-real=1000000 -d "$db" "${args[@]}"
