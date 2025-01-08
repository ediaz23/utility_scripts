#!/bin/bash

# Verificar si se ha pasado el archivo como argumento
if [ "$#" -ne 1 ]; then
  echo "Uso: $0 archivo"
  exit 1
fi

archivo="$1"

# Verificar si el archivo existe
if [ ! -f "$archivo" ]; then
  echo "Error: El archivo '$archivo' no existe."
  exit 1
fi

# Obtener el tipo MIME del archivo
mime_type=$(file --mime-type -b "$archivo")

# Convertir el archivo a base64
base64_data=$(base64 -w 0 "$archivo")

# Construir la URI de datos
data_uri="data:${mime_type};base64,${base64_data}"

# Crear el JSON con el campo "url"
json="{\"url\": \"${data_uri}\"}"

# Mostrar el JSON
echo "$json"

