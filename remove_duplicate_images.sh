#!/bin/bash

# Ruta de la carpeta de imágenes
image_folder="$PWD/img_min"

mkdir -p "$image_folder"

# Tamaño de la miniatura (ajusta según tus preferencias)
thumbnail_size="200x150"

shopt -s nullglob

for i in "$PWD"/*.{jpeg,JPEG,JPG}; do
    mv "$i" "${i%.*}.jpg";
done

for filename_with_percent in "$PWD"/*\%*.jpg; do
    new_filename=$(echo "$filename_with_percent" | tr -d '%')
    mv "$filename_with_percent" "$new_filename"
done

# Iterar sobre archivos de imagen en la carpeta
for image_file in "$PWD"/*.jpg; do
    if [ -f "$image_file" ]; then
        # Obtener el nombre del archivo sin extensión
        filename=$(basename -- "$image_file")
        filename_noext="${filename%.*}"

        echo "$filename"
        # Redimensionar la imagen usando convert de ImageMagick
        convert "$image_file" -resize "$thumbnail_size" "$image_folder/$filename_noext.png"
    fi
done

for i in "$image_folder"/*.png; do
    if [ ! -e "$i" ]; then
        continue
    fi
    file_i="$i"
    echo "procesando $i"
    for j in "$image_folder"/*.png; do
        if [ ! -e "$j" ]; then
            continue
        fi
        if [ "$file_i" != "$j" ]; then
            error=$(compare -metric PSNR "$file_i" "$j" null: 2>&1)
            if [[ "$error" =~ ^[0-9]+%$ ]]; then
                echo "$i $j $error"
                exit 1
            fi
            psnr=$(compare -metric PSNR "$file_i" "$j" null: 2>&1)
            if [ "$psnr" == "inf" ]; then
                psnr="100.0"
            fi
            psnr=$(echo "$psnr" | sed 's/dB//')
            if (( $(echo "$psnr > 17" | bc -l) )); then
                size_i=$(stat -c %s "$file_i")
                size_j=$(stat -c %s "$j")
                to_del=""
                if [ "$size_i" -lt "$size_j" ]; then
                    to_del="$file_i"
                    file_i=$j
                else
                    to_del="$j"
                fi
                rm -f "$to_del"
                to_del="${to_del##*/}"
                to_del="$PWD/${to_del%.*}.jpg"
                echo "    del $to_del"
                rm -f "$to_del"
            fi
        fi
    done
    rm -f "$file_i"
done

shopt -u nullglob
rm -f "$image_folder"/*.png
rmdir "$image_folder"

