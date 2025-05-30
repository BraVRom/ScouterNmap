#!/bin/bash

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

print_banner() {
    echo -e "${RED} 
      ::::::::   ::::::::   ::::::::  :::    ::: ::::::::::: :::::::::: :::::::::
    :+:       :+:    :+: :+:    :+: :+:    :+:     :+:     :+:        :+:    :+:  
  +#++:++#++ +#+        +#+    +:+ +#+    +#+     +#+     +#++:++#   +#++:++#:    
        +#+ +#+        +#+    +#+ +#+    +#+     +#+     +#+        +#+    +#+   
########   ########   ########   ########      ###     ########## ###    ###    
                ::::    :::   :::   :::       :::     :::::::::
               :+:+:   :+:  :+:+: :+:+:    :+: :+:   :+:    :+: 
               +#+ +:+ +#+ +#+  +:+  +#+ +#++:++#++: +#++:++#+  
              +#+  +#+#+# +#+       +#+ +#+     +#+ +#+        
             ###    #### ###       ### ###     ### ###
             
         		  ║┄║┄║ Coded by Br4hx ║┄║┄║
        		  https://github.com/BraVRom
      
 ${RESET}"
    sleep 1
}

# Validación parámetros IP o dominio
if [ "$#" -ne 1 ]; then
    echo -e "${RED}[!] Uso correcto: $0 <IP o dominio>${RESET}"
    exit 1
fi

host="$1"

# regex simple
if ! [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$host" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    echo -e "${RED}[!] El parámetro debe ser una IP o un dominio válido.${RESET}"
    exit 1
fi

print_banner

timestamp=$(date "+%Y-%m-%d_%H-%M-%S")  # timestamp
outdir="scan_${host}_${timestamp}"
html_out="$outdir/reporte_nmap.html"
mkdir -p "$outdir"

echo -e "${CYAN}[*] Escaneando puertos en $host...${RESET}"

nmap_output="$outdir/nmap_raw.txt"

# Uso de nmap sin redirigir salida y con la opción -oN (normal output) para guardar en archivo
nmap -p- -sS -sC -sV -Pn -n "$host" -oN "$nmap_output"
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Error ejecutando nmap.${RESET}"
    exit 1
fi

mapfile -t resultados < <(awk '
    /^PORT/{flag=1; next} 
    /^Nmap done:/{flag=0} 
    flag && /open/ && $2=="open"
' "$nmap_output")

if [ ${#resultados[@]} -eq 0 ]; then
    echo -e "${RED}[!] No se encontraron puertos abiertos.${RESET}"
    exit 1
fi

echo -e "${GREEN}[+] Puertos abiertos detectados: ${#resultados[@]}${RESET}"

obtener_http_title() {
    local ip="$1"
    local port="$2"
    local proto="$3"
    local url="${proto}://${ip}:${port}"

    # Solo curl si el servicio es http o https
    if [[ "$proto" == "http" || "$proto" == "https" ]]; then
        # Timeout 5 segundos
        local title=$(curl -s --max-time 5 -k "$url" | grep -oP '(?<=<title>).*?(?=</title>)' | head -n1)
        [[ -z "$title" ]] && title="—"
        echo "$title"
    else
        echo "—"
    fi
}

{
cat <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Reporte Nmap - $host</title>
<style>
    @import url('https://fonts.googleapis.com/css2?family=Fira+Code&display=swap');

    :root {
        --bg: #0f111a;
        --card-bg: rgba(255, 255, 255, 0.04);
        --text: #ffffffcc;
        --accent: #00ffe1;
        --green: #00e676;
        --red: #ff1744;
        --font: 'Fira Code', monospace;
    }

    * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
    }

    body {
        font-family: var(--font);
        background: var(--bg);
        color: var(--text);
        padding: 30px;
        line-height: 1.6;
    }

    h1 {
        text-align: center;
        color: var(--accent);
        margin-bottom: 10px;
        font-size: 2rem;
        animation: fadeIn 1s ease-in-out;
    }

    p.info {
        text-align: center;
        margin-bottom: 25px;
        color: #aaa;
        font-size: 0.95rem;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        background: var(--card-bg);
        backdrop-filter: blur(10px);
        border-radius: 10px;
        overflow: hidden;
        box-shadow: 0 0 20px rgba(0,0,0,0.2);
        animation: fadeIn 1.5s ease-in-out;
    }

    th, td {
        padding: 15px 20px;
        border-bottom: 1px solid rgba(255,255,255,0.05);
        text-align: left;
    }

    th {
        background: rgba(255, 255, 255, 0.06);
        color: var(--accent);
        text-transform: uppercase;
        font-size: 0.85rem;
        letter-spacing: 1px;
    }

    td.estado-open {
        color: var(--green);
        font-weight: bold;
    }

    td.estado-closed {
        color: var(--red);
        font-weight: bold;
    }

    tr:hover {
        background-color: rgba(255, 255, 255, 0.05);
        transition: 0.3s ease;
    }

    footer {
        margin-top: 30px;
        text-align: center;
        font-size: 0.8rem;
        color: #666;
        font-style: italic;
    }

    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-10px); }
        to { opacity: 1; transform: translateY(0); }
    }

    .badge {
        background: var(--accent);
        color: black;
        padding: 2px 8px;
        font-size: 0.75rem;
        border-radius: 4px;
    }
</style>
</head>
<body>

<h1>Reporte de Escaneo Nmap</h1>
<p class="info">
    <span class="badge">Host:</span> $host &nbsp; | &nbsp;
    <span class="badge">Fecha:</span> $(date "+%Y-%m-%d %H:%M:%S")
</p>

<table>
<thead>
    <tr>
        <th>Puerto</th>
        <th>Estado</th>
        <th>Servicio</th>
        <th>Versión</th>
        <th>Título HTTP</th>
    </tr>
</thead>
<tbody>
EOF
} > "$html_out"

for linea in "${resultados[@]}"; do
    local_linea="$linea"
    puerto=$(echo "$local_linea" | awk '{print $1}')
    estado=$(echo "$local_linea" | awk '{print $2}')
    servicio=$(echo "$local_linea" | awk '{print $3}')
    version=$(echo "$local_linea" | cut -d' ' -f4-)
    port_num=$(echo "$puerto" | cut -d'/' -f1)
    
    # comprueba si el servicio es HTTPS (puerto típico)
    if [[ "$port_num" == "443" || "$port_num" == "8443" ]]; then
        proto="https"
    elif [[ "$servicio" == "http" || "$servicio" == "https" ]]; then
        proto="$servicio"
    else
        proto=""
    fi

    if [[ -n "$proto" ]]; then
        titulo=$(obtener_http_title "$host" "$port_num" "$proto")
    else
        titulo="—"
    fi

    echo "<tr><td>$puerto</td><td>$estado</td><td>$servicio</td><td>$version</td><td>$titulo</td></tr>" >> "$html_out"
done

echo "</tbody></table>" >> "$html_out"

echo "<p style=\"text-align:center; margin-top:20px;\">" >> "$html_out"
echo "  🔗 <a href='https://www.shodan.io/host/$host' target='_blank'>Ver en Shodan</a> | " >> "$html_out"
echo "  📋 <a href='#' onclick=\"navigator.clipboard.writeText('$host');alert('IP copiada');\">Copiar IP</a>" >> "$html_out"
echo "</p>" >> "$html_out"

hash=$(sha256sum "$html_out" | awk '{print $1}')
fecha=$(date "+%Y-%m-%d_%H-%M-%S")

echo "<footer>" >> "$html_out"
echo "Hash SHA256 del reporte: <code>$hash</code><br>" >> "$html_out"
echo "Script by <a href='https://github.com/BraVRom' target='_blank'>Br4hx</a> | $fecha" >> "$html_out"
echo "</footer>" >> "$html_out"

echo "</body></html>" >> "$html_out"

echo -e "${GREEN}[✓] Reporte HTML generado en: ${html_out}${RESET}"

if [ -n "$DISPLAY" ] && command -v xdg-open &>/dev/null; then
    xdg-open "$html_out" &>/dev/null &
fi
