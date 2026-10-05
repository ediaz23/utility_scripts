#!/usr/bin/env bash
# Revisa que actualizaciones hay para un requirements.txt.
set -uo pipefail

PY="${PYTHON:-python3.12}"
NIVEL=""

usage() {
    cat <<'EOF'
Uso: up_requirements.sh [-u NIVEL] [-h] [requirements.txt]

Compara el piso declarado de cada paquete contra la ultima version en PyPI
y reporta si conviene subirlo. Sin -u no modifica nada.

Opciones:
  -u NIVEL   Reescribe el archivo subiendo los pisos. NIVEL puede ser:
               minor   solo cambios menores/patch (bajo riesgo)
               major   solo cambios de version mayor
               all     ambos
  -h         Muestra esta ayuda.

Notas:
  - Las lineas de git/URL y las opciones (-r, -e) se ignoran.
  - Un paquete que no se pueda consultar en PyPI se marca y se salta.
  - Los paquetes bloqueados por un cap (<X) nunca se actualizan: subir el
    piso por encima del tope dejaria un rango imposible. El cap se mueve
    a mano.
  - Con -u el archivo se reescribe en el sitio. Conviene tenerlo versionado.
EOF
}

while getopts ':u:h' opt; do
    case "$opt" in
        u) NIVEL="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "La opcion -$OPTARG necesita un nivel (minor|major|all)" >&2; exit 1 ;;
        ?) echo "Opcion desconocida: -$OPTARG" >&2; usage >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ -n "$NIVEL" ] && [ "$NIVEL" != 'minor' ] && [ "$NIVEL" != 'major' ] && [ "$NIVEL" != 'all' ]; then
    echo "Nivel invalido: $NIVEL (usa minor, major o all)" >&2
    exit 1
fi

REQ="${1:-requirements.txt}"
[ -f "$REQ" ] || { echo "No existe $REQ" >&2; exit 1; }

# a >= b usando orden de versiones
ver_ge() {
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

major() { echo "${1%%.*}"; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
CAMBIOS=0

printf '%-22s %-12s %-12s %s\n' PAQUETE DECLARADO ULTIMA ESTADO
printf '%s\n' "---------------------------------------------------------------------------"

while IFS= read -r raw || [ -n "$raw" ]; do
    salida="$raw"
    line="$(echo "${raw%%#*}" | tr -d '[:space:]')"
    name="${line%%[<>=!~;[]*}"

    # comentarios, opciones (-r, -e) y dependencias por URL/git pasan sin tocar
    case "$line" in
        ''|-*|git+*|http*|*@*) name="" ;;
    esac

    if [ -z "$name" ]; then
        printf '%s\n' "$salida" >> "$TMP"
        continue
    fi

    floor="$(echo "$line" | grep -oE '(>=|==|~=)[0-9][^,]*' | head -1 | sed -E 's/^(>=|==|~=)//')"
    cap="$(echo "$line" | grep -oE '<=?[0-9][^,]*' | head -1 | sed -E 's/^<=?//')"

    latest="$("$PY" -m pip index versions "$name" 2>/dev/null \
              | head -1 | sed -E 's/.*\(([^)]*)\).*/\1/')"

    if [ -z "$latest" ]; then
        printf '%-22s %-12s %-12s %s\n' "$name" "${floor:-—}" "?" "no se pudo consultar — ignorado"
        printf '%s\n' "$salida" >> "$TMP"
        continue
    fi

    tipo=""
    if [ -z "$floor" ]; then
        estado="sin piso declarado"
    elif [ "$floor" = "$latest" ]; then
        estado="al dia"
    elif ! ver_ge "$latest" "$floor"; then
        estado="declarado por encima de PyPI (revisar)"
    elif [ -n "$cap" ] && ver_ge "$latest" "$cap"; then
        estado="BLOQUEADO por el cap <$cap"
    elif [ "$(major "$floor")" != "$(major "$latest")" ]; then
        estado="MAJOR $(major "$floor")->$(major "$latest") — revisar changelog"
        tipo="major"
    else
        estado="menor/patch — bajo riesgo"
        tipo="minor"
    fi

    if [ -n "$tipo" ] && [ -n "$NIVEL" ] && { [ "$NIVEL" = 'all' ] || [ "$NIVEL" = "$tipo" ]; }; then
        esc="$(printf '%s' "$floor" | sed -e 's/[.[\*^$/]/\\&/g')"
        salida="$(printf '%s' "$raw" | sed -E "s/(>=|==|~=)${esc}/\1${latest}/")"
        estado="$estado  [actualizado]"
        CAMBIOS=$((CAMBIOS + 1))
    fi

    printf '%-22s %-12s %-12s %s\n' "$name" "${floor:-—}" "$latest" "$estado"
    printf '%s\n' "$salida" >> "$TMP"
done < "$REQ"

if [ -n "$NIVEL" ]; then
    if [ "$CAMBIOS" -gt 0 ]; then
        cat "$TMP" > "$REQ"
        echo
        echo "$REQ actualizado: $CAMBIOS linea(s) con nivel '$NIVEL'."
    else
        echo
        echo "Nada que actualizar con nivel '$NIVEL'. $REQ sin cambios."
    fi
fi
