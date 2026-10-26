#!/bin/bash
# Instala la última versión de una línea de node (ej: 22) y desinstala las demás de esa línea, salvo las de "keep".
# Si el alias default apuntaba a esa línea, lo mueve a la versión nueva.
# Uso: nvm_upgrade_node.sh 22

# Versiones exactas que nunca se desinstalan
keep=(
    v20.12.2   # webOS TV 26
    v16.20.2   # webOS TV 25
    v16.19.1   # webOS TV 24
    v12.22.2   # webOS TV 23
    v12.21.0   # webOS TV 22
    v8.12.0    # webOS TV 6.0 y 5.0
    v0.12.2    # webOS TV 4.x y 3.x
    v0.10.25   # webOS TV 2.x
    v0.10.15   # webOS TV 1.x
)

version="$1"

if [ -z "$version" ]; then
    echo "Uso: $0 <version_node>   (ej: $0 22)" >&2
    exit 1
fi

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
source "$NVM_DIR/nvm.sh"

installed=$(nvm_ls "$version" | grep '^v')
current=$(nvm version "$version")
new=$(nvm version-remote "$version") || exit 1
default_target=$(nvm_alias default 2>/dev/null)

if [ "$current" = "N/A" ]; then
    nvm install "$new" || exit 1
elif [ "$current" != "$new" ]; then
    nvm install "$new" --reinstall-packages-from="$current" || exit 1
fi

if [[ "v${default_target#v}" == "v$version" || "v${default_target#v}" == "v$version."* ]]; then
    nvm alias default "$new"
fi

for old in $installed; do
    if [ "$old" != "$new" ] && [[ " ${keep[*]} " != *" $old "* ]]; then
        nvm uninstall "$old"
    fi
done

echo "node $version: $current -> $new"
