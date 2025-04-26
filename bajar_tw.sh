#!/bin/bash

url="${1%/*}"
name="$2"

temp_dir=$(mktemp -d);
echo "tmp_dir $temp_dir";
cd "$temp_dir";
echo "$url"

i=0
while true; do
    if ! wget -4 -c "$url/video$i.ts"; then
        echo "termino la descarga"
        break
    fi
    ((i++))
done

count=$(ls *.ts 2>/dev/null | wc -l)
base=$(echo "scale=0; l($count)/l(10)" | bc -l)
limit=$(echo "scale=0; 10^$base" | bc -l)

base=$((base+1))
for ((i=0;i<$limit;i++)); do
    if [ -e "video$i.ts" ]; then
        relleno=$(printf "%0${base}d" "$i")
        mv "video$i.ts" "video$relleno.tts";
    fi;
done

for i in *.ts;
do
    mv "$i" "${i%.*}.tts"
done

cat *.tts > big.ts
rm *.tts

if [ -z "$name" ]; then
    name="${url%/*}"
    name="${name##*/}"
fi

ffmpeg -i big.ts -c:v libx264 -c:a aac "$name.mp4"
cd -;
echo "archivo $temp_dir/$name.mp4"
mv "$temp_dir/$name.mp4" .
rm -rf "$temp_dir";
