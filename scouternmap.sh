#!/bin/bash

GREEN="\e[1;32m"
RED="\e[1;31m"
RESET="\e[0m"

# Banner
print_banner() {
    echo -e "${RED}
      ::::::::   ::::::::   ::::::::  :::    ::: ::::::::::: :::::::::: :::::::::::
    :+:    :+: :+:    :+: :+:    :+: :+:    :+:     :+:     :+:        :+:    :+:
   +:+        +:+        +:+    +:+ +:+    +:+     +:+     +:+        +:+    +:+ 
  +#++:++#++ +#+        +#+    +:+ +#+    +:+     +#+     +#++:++#   +#++:++#:   
        +#+ +#+        +#+    +#+ +#+    +#+     +#+     +#+        +#+    +#+   
#+#    #+# #+#    #+# #+#    #+# #+#    #+#     #+#     #+#        #+#    #+#    
########   ########   ########   ########      ###     ########## ###    ###     
                  ::::    :::   :::   :::       :::     :::::::::                
                 :+:+:   :+:  :+:+: :+:+:    :+: :+:   :+:    :+:                
                :+:+:+  +:+ +:+ +:+:+ +:+  +:+   +:+  +:+    +:+                  
               +#+ +:+ +#+ +#+  +:+  +#+ +#++:++#++: +#++:++#+                    
              +#+  +#+#+# +#+       +#+ +#+     +#+ +#+                        
             #+#   #+#+# #+#       #+# #+#     #+# #+#+                          
            ###    #### ###       ### ###     ### ###                            

                      │█║▌║▌║ Coded by Br4hx ║▌║▌║
		       https://github.com/BraVRom
 ${RESET}"
    sleep 1
}

# Finaliza y limpia
cleanup() {
    echo -e "\n${RED}[*] Terminando el escáner...${RESET}\n"
    [ -f open_ports.log ] && rm open_ports.log
    [ -f results ] && rm results
    exit
}

trap cleanup SIGINT

# Banner
print_banner

# Comprobar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[*] Error: Usar sudo.${RESET}"
    exit 1
fi

# Validar IP
validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
        return 0  # IP válida
    else
        return 1  # IP no válida
    fi
}

if [ $# -eq 1 ]; then
    if validate_ip "$1"; then
        target_ip="$1"
    else
        echo -e "${RED}[*] Introduzca una dirección IPv4 válida.${RESET}"
        exit 1
    fi
else
    echo -e "${RED}[*] Debes poner una IP para escanear.${RESET}"
    exit 1
fi

# Escaneo de puertos
echo -e "${GREEN}[*] Iniciando escaneo en $target_ip...${RESET}"
if ! nmap -p- -sS --open -Pn "$target_ip" -oG open_ports.log; then
    echo -e "${RED}[*] Error al ejecutar nmap.${RESET}"
    exit 1
fi

found_ports=$(grep -oP '\d{1,5}/open' open_ports.log | awk -F '/' '{print $1}' | tr '\n' ',' | sed 's/,$//')

# Salida de resultados
if [ -z "$found_ports" ]; then
    echo -e "${RED}[*] No se detectaron puertos abiertos en $target_ip.${RESET}"
    rm open_ports.log
    exit 1
else
    total_ports=$(echo "$found_ports" | tr ',' '\n' | wc -l)
    echo -e "${GREEN}[*] Puertos abiertos encontrados: $found_ports${RESET}"
    echo -e "${GREEN}[*] Se escanearon un total de $total_ports puertos.${RESET}"
fi

# Escaneo de servicios
echo -e "${GREEN}[*] Realizando escaneo a los servicios de $target_ip...${RESET}"
if ! nmap -sCV -p"$found_ports" "$target_ip" -oN results; then
    echo -e "${RED}[*] Error al realizar el escaneo de servicios.${RESET}"
    exit 1
fi

{
    echo -e "\n-> IP: $target_ip"
    echo -e "-> Puertos: $found_ports"
} >> results

rm open_ports.log
echo ""
echo -e "${GREEN}[*] Escaneo completado. Resultados guardados en 'results'.${RESET}"
