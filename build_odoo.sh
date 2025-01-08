#!/bin/bash
set -e

SCRIPT_NAME=$(basename "$0")

# Verificar si $1 está vacío
if [ -z "$1" ]; then
    echo "Falta version de odoo"
    exit 1
fi

odoo="$1.0"
echo "Compilando odoo $odoo"

echo "Copiando carpeta odoo"
mkdir odoo
cp -a ../../addons/odoo_base/. ./odoo/

echo "Cambiando rama a $odoo"
cd odoo
git checkout $odoo
cd ..
rm -r ./odoo/.git

if [[ "$odoo" == "18.0" || "$odoo" == "17.0" ]]; then
    echo "patch para requirements $odoo"
    sed -i 's/gevent==21\.8\.0/gevent==22.10.2/g' ./odoo/requirements.txt
    sed -i 's/greenlet==1\.1\.2/greenlet==2.0.2/g' ./odoo/requirements.txt
fi

echo "Copiando archivos de configuracion"
cp -a ../docker_git/$odoo/. ./

find . -maxdepth 1 -mindepth 1 -not -name $SCRIPT_NAME -exec echo {} +

echo "Construyendo imagen odoo:$odoo"
docker build -t odoo:$odoo . --no-cache --network=host

echo "Borrando"
find . -maxdepth 1 -mindepth 1 -not -name $SCRIPT_NAME -exec echo {} +
find . -maxdepth 1 -mindepth 1 -not -name $SCRIPT_NAME -exec rm -rf {} +
