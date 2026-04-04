#!/bin/bash

url="$1"
name="$2"

temp_dir=$(mktemp -d);
echo "tmp_dir $temp_dir";
cd "$temp_dir";

if [[ "$url" == *.m3u8* ]]; then
    origin="https://waaw.to";
    wget --header="Accept-Encoding: gzip" \
         --header="Origin: $origin" \
         --header="Referer: $origin" \
         --header='sec-ch-ua: "Chromium";v="110", "Not A(Brand";v="24", "Google Chrome";v="110"' \
         "$url" -O raw_manifest || exit 1
    
    if ! cat raw_manifest | gzip -d > manifest.xml 2>/dev/null; then
        mv raw_manifest manifest.xml;
    fi

    rm raw_manifest

    if [[ "$url" == *silverlight* ]]; then
        prefix="${url##*/}"
        prefix="${prefix%%.*}"
        base_url="${url%/*}/$prefix"
        sed -i "s|$prefix|$base_url|g" ./manifest.xml
    fi
    
    while read -r f; do
        wget --header="Accept-Encoding: gzip" \
             --header="Origin: $origin" \
             --header="Referer: $origin" \
             --header='sec-ch-ua: "Chromium";v="110", "Not A(Brand";v="24", "Google Chrome";v="110"' \
             $f
        sleep 0.5
    done <<< "$(grep -Eo 'http[^"]+' manifest.xml)"
else
    base_url="${url%/*}"
    i=0
    while true; do
        if ! wget -4 -c "$base_url/video$i.ts"; then
            echo "termino la descarga"
            break
        fi
        sleep 0.5
        i=$((i+1))
    done
fi

shopt -s nullglob  # para que explanda el $pattern
count=$(ls -1 . 2>/dev/null | grep -v manifest.xml | wc -l)
base=$(echo "scale=0; l($count)/l(10)" | bc -l)
base=$((base+1))

i=1
while read -r f; do
    relleno=$(printf "%0${base}d" "$i")
    mv "$f" "video${relleno}.tts"
    i=$((i+1))
done <<< "$(ls -1t --time=ctime | grep -v manifest.xml | tac)"

first=$(ls *.tts | head -n1)

if gzip -dc "$first" >/dev/null 2>&1; then
    mode="gzip"
elif xxd -l 8 "$first" | grep -qi "PNG"; then
    mode="png"
else
    mode="raw"
fi

echo "Modo detectado: $mode"

for f in *.tts; do
    if [ "$mode" = "gzip" ]; then
        gzip -dc "$f" >> big.ts 2>/dev/null
    elif [ "$mode" = "png" ]; then
        tail -c +70 "$f" >> big.ts
    else
        cat "$f" >> big.ts
    fi
done
shopt -s nullglob

rm *.tts

if [ -z "$name" ]; then
    name="${url%/*}"
    name="${name##*/}"
fi

ffmpeg -threads 16 -crf 23 -preset medium -i big.ts -c:v libx264 -c:a aac "$name.mp4"
cd -;
echo "archivo $temp_dir/$name.mp4"
mv "$temp_dir/$name.mp4" .
rm -rf "$temp_dir";
