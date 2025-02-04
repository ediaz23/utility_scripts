#!/bin/bash

# Ruta de la carpeta de videos
video_folder="$PWD/vid_min"

mkdir -p "$video_folder"

# Tamaño de la miniatura (puedes ajustarlo según tus preferencias)
thumbnail_size="200x150"

shopt -s nullglob

for i in "$PWD"/*.{m4v,mov,MOV,MP4}; do
    mv "$i" "${i%.*}.mp4";
done

for filename_with_percent in "$PWD"/*\%*.mp4; do
    new_filename=$(echo "$filename_with_percent" | tr -d '%')
    mv "$filename_with_percent" "$new_filename"
done

shopt -u nullglob

# Iterar sobre archivos de video en la carpeta
for video_file in "$PWD"/*.mp4; do
    if [ -f "$video_file" ]; then
        # Obtener el nombre del archivo sin extensión
        filename=$(basename -- "$video_file")
        filename_noext="${filename%.*}"

        echo "$filename"
        # Obtiene la duración del video en segundos
        duration=$(ffmpeg -i "$video_file" 2>&1 | grep "Duration" | awk '{print $2}' | tr -d , | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')

        # Condiciona el segundo de la captura según la duración del video
        if (( $(echo "$duration < 30" | bc -l) )); then
          ss_time="00:00:02"
        else
          ss_time="00:00:30"
        fi
        # Tomar una captura de pantalla del video usando ffmpeg
        ffmpeg -i "$video_file" -ss "$ss_time" -vframes 1 "$video_folder/$filename_noext-big.jpg" 2>/dev/null
        if [ -f "$video_folder/$filename_noext-big.jpg" ]; then
            # Redimensionar la miniatura usando convert de ImageMagick
            convert "$video_folder/$filename_noext-big.jpg" -resize "$thumbnail_size" "$video_folder/$filename_noext.png"

            # Eliminar la captura de pantalla original
            rm "$video_folder/$filename_noext-big.jpg"
        fi
    fi
done


for i in "$video_folder"/*.png; do
    if [ ! -e "$i" ]; then
        continue
    fi
    file_i="$i"
    echo "procesando $i"
    for j in "$video_folder"/*.png; do
        if [ ! -e "$j" ]; then
            continue
        fi
        if [ "$file_i" != "$j" ]; then
            psnr=$(compare -metric PSNR "$file_i" "$j" null: 2>&1)
            if [ "$psnr" == "inf" ]; then
                psnr="100.0"
            fi
            psnr=$(echo "$psnr" | sed 's/dB//')
            if (( $(echo "$psnr > 16.5" | bc -l) )); then
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
                to_del="$PWD/${to_del%.*}.mp4"
                echo "    del $to_del"
                rm -f "$to_del"
            fi
        fi
    done
    rm -f "$file_i"
done

rm -f "$video_folder"/*.png
rmdir "$video_folder"


