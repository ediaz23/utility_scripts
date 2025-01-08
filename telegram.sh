#!/bin/bash

while true; do
    # Ejecutar el comando de prueba
    python3 telegram.py
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        # Si el comando prueba termina bien, salir del bucle
        break
    else
        # Encontrar el archivo más antiguo (excluyendo archivos específicos)
        ultimo_archivo=$(ls -t | grep -E -v "^(telegram\.sh|telegram\.py|downloader\.session|data\.json)$" | head -n1)

        # Verificar si hay un archivo para borrar
        if [ -n "$ultimo_archivo" ]; then
            echo "Borrando el archivo más antiguo: $ultimo_archivo"
            rm "$ultimo_archivo"
        else
            echo "No hay archivos adecuados en la carpeta para borrar."
            break
        fi
    fi
    sleep 2
done

