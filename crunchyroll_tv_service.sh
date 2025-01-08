#!/bin/bash

current_date=$(date "+%Y-%m-%d %H:%M:%S")
echo $current_date
echo ""

# Imprimir encabezados
printf "%-5s %-40s %-6s %-9s %-12s\n" "PID" "ID" "CPU(%)" "MEMORY(%)" "MEMORY(KB)"
printf "%-5s %-40s %-6s %-9s %-12s\n" "----" "--------------------------" "------" "---------" "----------"

# Obtener y formatear la información del proceso
ares-novacom -d tv1 --run 'ps aux | grep \[c\]om.crunchyroll.stream.app.service' 2>/dev/null | awk '{printf "%-5s %-40s %-6s %-9s %-12.2f\n", $2, $11, $3, $4, $6/1024}'

echo -e "\n"
ares-device-info -d tv1 -r -id com.crunchyroll.stream.app
