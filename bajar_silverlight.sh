#!/bin/bash

url="$1"

temp_dir=$(mktemp -d);
echo "tmp_dir $temp_dir";
cd "$temp_dir";

wget --header="Accept-Encoding: gzip" --header="Origin: https://waaw.to" --header="Referer: https://waaw.to/" --header='sec-ch-ua: "Chromium";v="110", "Not A(Brand";v="24", "Google Chrome";v="110"' "$url" -O raw_manifest

if ! cat raw_manifest | gzip -d > manifest.xml 2>/dev/null; then
    mv raw_manifest manifest.xml;
fi

prefix="${url##*/}"
sed -i "s|$prefix|$url|g" ./manifest.xml

wget --header="Accept-Encoding: gzip" --header="Origin: https://waaw.to" --header="Referer: https://waaw.to/" --header='sec-ch-ua: "Chromium";v="110", "Not A(Brand";v="24", "Google Chrome";v="110"' -i <(grep -Eo 'http[^"]+' manifest.xml)

count=$(ls Frag* 2>/dev/null | wc -l)
base=$(echo "scale=0; l($count)/l(10)" | bc -l)
limit=$(echo "scale=0; 10^$base" | bc -l)

base=$((base+1))
for ((i=1;i<$limit;i++)); do
    if [ -e "Frag-$i-v1-a1" ]; then
        relleno=$(printf "%0${base}d" "$i")
        mv "Frag-$i-v1-a1" "Frag-$relleno-v1-a1";
    fi;
done

for i in F*; do
    if ! cat $i | gzip -d > "$i.tts" 2>/dev/null; then
        mv $i "$i.tts";
    fi
done

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
rm -rf "$temp_dir";
