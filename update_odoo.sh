#!/bin/bash

# Solicitar usuario y contraseña
read -p "Usuario: " username
read -s -p "Contraseña: " password
echo

# Crear archivo temporal para GIT_ASKPASS
GIT_ASKPASS=$(mktemp)
chmod +x "$GIT_ASKPASS"
cat <<EOF >"$GIT_ASKPASS"
#!/bin/bash
echo $password
EOF

# Asegurar eliminación del archivo temporal al terminar el script
trap 'rm -f "$GIT_ASKPASS"' EXIT

# Exportar GIT_ASKPASS para usar credenciales temporalmente
export GIT_USERNAME=$username
export GIT_ASKPASS="$GIT_ASKPASS"

# Usar el primer argumento como lista de ramas (separadas por comas) o un valor por defecto
if [[ -n "$1" ]]; then
    IFS=',' read -r -a branches <<< "$1"
else
    branches=("11.0" "12.0" "13.0" "14.0" "15.0" "16.0" "17.0" "18.0")
fi

# Iterar por cada rama
for branch in "${branches[@]}"; do
    echo "Cambiando a la rama: $branch"
    if ! git checkout "$branch"; then
        echo "Error al cambiar a la rama $branch. Continuando con la siguiente..."
        continue
    fi

    echo "Haciendo git pull en la rama: $branch"
    if ! git -c core.askpass="$GIT_ASKPASS" pull; then
        echo "Error al hacer pull en la rama $branch. Continuando con la siguiente..."
        continue
    fi

    echo "Haciendo git rebase no interactivo en HEAD~3"
    if ! GIT_EDITOR=":" git rebase -i --autosquash HEAD~3; then
        echo "Resolviendo conflictos automáticamente durante el rebase en $branch"
        git add -A
        if ! git rebase --continue; then
            echo "Error al continuar el rebase en la rama $branch. Abortando rebase..."
            git rebase --abort
            continue
        fi
    fi

done

echo "Ejecutando git gc --aggressive --prune=now"
if ! git gc --aggressive --prune=now; then
    echo "Error al ejecutar git gc en la rama $branch. Continuando..."
fi

echo "Script completado exitosamente."

