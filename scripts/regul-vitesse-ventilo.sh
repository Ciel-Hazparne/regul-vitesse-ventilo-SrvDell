#!/bin/bash

# Config IPMI
IP="IP_IDRAC"
USER="utilisateur"
PASSWORD="mot_de_passe"

# Dossiers de log
LOG="/var/log/ipmi"
mkdir -p "$LOG"

# Date
DATE=$(date +%Y-%m-%d)
HEURE=$(date +%H:%M:%S)

# Email (si alerte)
DE="email"
A="email"
SENDMAIL="/usr/sbin/sendmail"

# Initialisation
total_erreur=0
NEWFANS=30  # Valeur par défaut si tout va bien

# Lecture des températures
sensors_output=$(ipmitool -I lanplus -H "$IP" -U "$USER" -P "$PASSWORD" sdr type Temperature)

# Extraction brute de toutes les températures (en nombre entier)
TEMP_LIST=$(echo "$sensors_output" | grep -E 'Temp|Inlet|Exhaust' | awk -F'|' '{print $5}' | grep -oE '[0-9]+' || true)

# Sécurité : vérifier qu'on a bien des températures
if [ -z "$TEMP_LIST" ]; then
    echo "[$DATE $HEURE] Erreur de lecture des capteurs (aucune température récupérée)" >> "$LOG/error.log"
    NEWFANS=100
    ((total_erreur++))
fi

# Détermination de la température maximale
TEMP_MAX=0
for T in $TEMP_LIST; do
    if [ "$T" -gt "$TEMP_MAX" ]; then
        TEMP_MAX=$T
    fi
done

# Régulation basée sur la température max
if   [ "$TEMP_MAX" -ge 70 ]; then NEWFANS=100
elif [ "$TEMP_MAX" -ge 60 ]; then NEWFANS=80
elif [ "$TEMP_MAX" -ge 50 ]; then NEWFANS=50
elif [ "$TEMP_MAX" -ge 45 ]; then NEWFANS=30
elif [ "$TEMP_MAX" -ge 35 ]; then NEWFANS=20
else                              NEWFANS=10
fi