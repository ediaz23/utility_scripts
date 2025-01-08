#!/bin/bash

offset=0
save=false
hasName=false
padding=2
ext='mp4'

while [[ $# -gt 0 ]]; do
    case $1 in
        -name)
            shift
            name=$1
            hasName=true
            ;;
        -offset)
            shift
            offset=$1
            ;;
        -padding)
            shift
            padding=$1
            ;;
        -save)
            save=true
            ;;
        -ext)
            shift
            ext=$1
            ;;
        -h)
            echo -e "Opciones \n-name nombre a usar \n-offset number a suabar \n-padding completar con ceros \n-save renombrar \n-ext extension"
            exit 1
            ;;
        *)
            echo "Opción desconocida: $1 -h para ayuda"
            exit 1
            ;;
    esac
    shift
done

if ! $hasName; then
    echo "Se debe proporcionar el parámetro -name"
    exit 1
fi

for i in *.$ext;
do
    j="${i#*-}";
    j="${j##* }";
    j="${j#0}";
    j="${j%%.*}";
    j="${j%% *}";
    j="${j%%-*}";
    j=$((j+offset));
    j=$(printf "%0${padding}d" $j);
    echo "$name $j.$ext";
    if $save; then
        mv "$i" "$name $j.$ext";
    fi
done

