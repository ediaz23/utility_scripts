#!/bin/bash

SCRIPT_NAME=$(basename "$0")

# Lista de archivos a ignorar, incluyendo el propio script
IGNORE_LIST=("$SCRIPT_NAME" "LICENSE" "generate_aws_token.js" "telegram.py" "telegram.sh" "build_odoo.sh")

# Recorrer los archivos y carpetas en el directorio actual
for file in *; do
    # Ignorar archivos ocultos
    if [[ "$file" == .* ]]; then
        continue
    fi

    # Verificar si el archivo está en la lista de ignorados
    if [[ " ${IGNORE_LIST[@]} " =~ " $file " ]]; then
        continue
    fi

    if [[ "$1" == "--remove" ]]; then
        echo "removing $file"
        rm -f ~/.local/bin/${file%.*};
    else
        echo "installing $file"
        chmod +x "$file";
        ln -s $PWD/$file ~/.local/bin/${file%.*};
    fi
done
