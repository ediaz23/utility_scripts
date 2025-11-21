#!/bin/bash

url="$1"

temp_dir=$(mktemp -d);
echo "tmp_dir $temp_dir";
cd "$temp_dir";
origin="https://waaw.to";

wget --header="Accept-Encoding: gzip" --header="Origin: $origin" --header="Referer: $origin" --header='sec-ch-ua: "Chromium";v="110", "Not A(Brand";v="24", "Google Chrome";v="110"' "$url" -O raw_manifest || exit 1

if ! cat raw_manifest | gzip -d > manifest.xml 2>/dev/null; then
    mv raw_manifest manifest.xml;
fi

prefix="${url##*/}"
sed -i "s|$prefix|$url|g" ./manifest.xml

wget --header="Accept-Encoding: gzip" --header="Origin: $origin" --header="Referer: $origin" --header='sec-ch-ua: "Chromium";v="110", "Not A(Brand";v="24", "Google Chrome";v="110"' -i <(grep -Eo 'http[^"]+' manifest.xml)

if grep -q "Frag-" manifest.xml 2>/dev/null;
then
    pattern="Frag*";
elif grep -qE "index[0-9]+\.ts" manifest.xml 2>/dev/null;
then
    pattern="index*.ts";
    for i in index*;
    do
        mv "$i" "${i%\?*}";
    done
else
    echo "formato no esperado"
    exit 0
fi

shopt -s nullglob  # para qu explanda el $pattern
count=$(ls $pattern 2>/dev/null | wc -l)
shopt -s nullglob
base=$(echo "scale=0; l($count)/l(10)" | bc -l)
limit=$(echo "scale=0; 10^$base" | bc -l)

base=$((base+1))
for ((i=1;i<$limit;i++)); do
    relleno=$(printf "%0${base}d" "$i")
    if [[ $pattern == Frag* ]]; then
        # Caso Frag
        if [ -e "Frag-$i-v1-a1" ]; then
            mv "Frag-$i-v1-a1" "Frag-$relleno-v1-a1"
        fi
    else
        # Caso indexX.ts
        if [ -e "index$i.ts" ]; then
            mv "index$i.ts" "index${relleno}.ts"
        fi
    fi
done

shopt -s nullglob  # para qu explanda el $pattern
for i in $pattern; do
    if ! gzip -dc "$i" > "$i.tts" 2>/dev/null; then
        mv "$i" "$i.tts"
    fi
done
shopt -s nullglob

cat *.tts > big.ts
rm *.tts

ffmpeg -i big.ts -c:v libx264 -c:a aac "$prefix.mp4"
cd -;
echo "archivo $temp_dir/$prefix.mp4"
if [[ -n "$2" ]]; then
    mv "$temp_dir/$prefix.mp4" "./$2.mp4"
else
    mv "$temp_dir/$prefix.mp4" .
fi
# rm -rf "$temp_dir";
