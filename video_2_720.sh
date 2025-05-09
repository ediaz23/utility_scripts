#!/bin/bash

for i in *.{m4v,mov,MOV,MP4}; do
    mv "$i" "${i%.*}.mp4" 2> /dev/null;
done

# Bucle para procesar cada vídeo en la carpeta
for video in *.mp4; do
    # Obtener la resolución del vídeo utilizando ffprobe
    resolucion=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video")

    # Extraer el ancho y el alto de la resolución
    ancho=$(echo "$resolucion" | cut -d ',' -f1)
    alto=$(echo "$resolucion" | cut -d ',' -f2)

    # Comprobar si la resolución es mayor que 720p
    if [ "$ancho" -gt 1280 ] && [ "$alto" -gt 720 ] || [ "$ancho" -gt 720 ] && [ "$alto" -gt 1280 ]; then
        # Calcular la nueva altura y anchura manteniendo la relación de aspecto
        if [ "$ancho" -gt "$alto" ]; then
            echo "  landscape"
            # Es un vídeo horizontal (landscape)
            nueva_anchura=$(echo "scale=2; 720 * $ancho / $alto" | bc)
            nueva_anchura=$(printf "%.0f" $nueva_anchura)  # Redondear hacia abajo al número par más cercano
            nueva_anchura=$((nueva_anchura - nueva_anchura % 2))  # Asegurar que la altura sea divisible por 2
            nueva_altura=720
        else
            # Es un vídeo vertical (portrait)
            nueva_altura=$(echo "scale=2; 720 * $alto / $ancho" | bc)
            nueva_altura=$(printf "%.0f" $nueva_altura)  # Redondear hacia abajo al número par más cercano
            nueva_altura=$((nueva_altura - nueva_altura % 2))  # Asegurar que la altura sea divisible por 2
            nueva_anchura=720
        fi
        # Convertir el vídeo a 720p manteniendo la relación de aspecto original
        # if ffmpeg -i "$video" -threads 16 -crf 24 -c:v libx264 -vf "scale=$nueva_anchura:$nueva_altura" -c:a aac "${video%.*}_720p.mp4"; then
        #    rm "$video";
        # fi
        
        if ffmpeg -y -i "$video" -threads 16 -c:v libx264 -preset veryslow -b:v 1500k -pass 1 -vf "scale=$nueva_anchura:$nueva_altura" -f mp4 /dev/null && \
           ffmpeg    -i "$video" -threads 16 -c:v libx264 -preset veryslow -b:v 1500k -pass 2 -vf "scale=$nueva_anchura:$nueva_altura" -c:a aac "${video%.*}_720p.mp4"; then
            rm "$video";
        fi
        echo "El vídeo $video a 720p. $ancho x $alto => $nueva_anchura x $nueva_altura"
    else
        if [[ ! $video =~ _720p\.mp4$ ]]; then
            if ffmpeg -y -i "$video" -threads 16 -c:v libx264 -preset veryslow -b:v 1500k -pass 1 -f mp4 /dev/null && \
               ffmpeg    -i "$video" -threads 16 -c:v libx264 -preset veryslow -b:v 1500k -pass 2 -c:a aac "${video%.*}_720p.mp4"; then
                rm "$video";
            fi
        fi
        echo "El vídeo $video crf $ancho x $alto"
    fi
    rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree;
done

