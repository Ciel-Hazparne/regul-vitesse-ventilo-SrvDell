#!/bin/bash
export TZ="Europe/Paris"

# Config IPMI
IP="IP_IDRAC"
USER="utilisateur"
PASSWORD="mot_de_passe"

# Dossiers de log
LOG="/var/log/ipmi"
mkdir -p "$LOG"

# Date / heure
DATE=$(date +%F)
HEURE=$(date +%T)

# Email (si alerte)
DE="ciel@esh64.fr"
A="ciel@esh64.fr"
SENDMAIL="/usr/sbin/sendmail"

# Initialisation
total_erreur=0
NEWFANS=30

# Lecture des températures via IPMI
sensors_output=$(ipmitool -I lanplus -H "$IP" -U "$USER" -P "$PASSWORD" sdr type Temperature 2>/dev/null || true)

# Extraction brute des températures numériques
TEMP_LIST=$(echo "$sensors_output" | grep -E 'Temp|Inlet|Exhaust' | awk -F'|' '{print $5}' | grep -oE '[0-9]+' || true)

# Sécurité : s’assurer qu'on a bien des températures exploitables
if [[ -z "$TEMP_LIST" ]]; then
    echo "[$DATE $HEURE] Erreur de lecture des capteurs : aucune température récupérée" >> "$LOG/error.log"
    NEWFANS=100
    ((total_erreur++))
else
    # Déterminer la température maximale
    TEMP_MAX=0
    for T in $TEMP_LIST; do
        if [[ "$T" =~ ^[0-9]+$ ]]; then
            (( T > TEMP_MAX )) && TEMP_MAX=$T
        fi
    done

    # Régulation en fonction de la température max
    if   [ "$TEMP_MAX" -ge 70 ]; then NEWFANS=100
    elif [ "$TEMP_MAX" -ge 60 ]; then NEWFANS=80
    elif [ "$TEMP_MAX" -ge 50 ]; then NEWFANS=30 # 3900 rpm
    elif [ "$TEMP_MAX" -ge 45 ]; then NEWFANS=20 # 3000 rpm
    elif [ "$TEMP_MAX" -ge 35 ]; then NEWFANS=15 # 2640 rpm
    else                              NEWFANS=10 # 2040 rpm
    fi

    echo "[$DATE $HEURE] Température max détectée : ${TEMP_MAX}°C" >> "$LOG/ipmitool.log"
    echo "[$DATE $HEURE] Vitesse ventilateurs demandée : ${NEWFANS} %" >> "$LOG/ipmitool.log"
fi

# Activation du mode manuel
ipmitool -I lanplus -H "$IP" -U "$USER" -P "$PASSWORD" raw 0x30 0x30 0x01 0x00 2>>"$LOG/error.log" || {
    echo "[$DATE $HEURE] Erreur : activation du mode manuel échouée" >> "$LOG/error.log"
    ((total_erreur++))
}

# Conversion décimal → hexadécimal
NEWFANS_HEX=$(printf "%x" "$NEWFANS")

# Log de la commande IPMI
echo "[$DATE $HEURE] Envoi IPMI : raw 0x30 0x30 0x02 0xff 0x$NEWFANS_HEX" >> "$LOG/ipmitool.log"

# Envoi IPMI de la consigne
ipmitool -I lanplus -H "$IP" -U "$USER" -P "$PASSWORD" raw 0x30 0x30 0x02 0xff 0x$NEWFANS_HEX 2>>"$LOG/error.log" || {
    echo "[$DATE $HEURE] Erreur : échec de l’envoi IPMI (NEWFANS=$NEWFANS)" >> "$LOG/error.log"
    ((total_erreur++))
}

# Envoi d’un email en cas d’erreur
if (( total_erreur > 0 )); then
    BODY="Bonjour,

Le script de gestion des ventilateurs a généré au moins une erreur.

Derniers messages du journal d'erreurs :
$(tail -n 10 "$LOG/error.log" 2>/dev/null || echo 'Aucun message.')

Fichiers à consulter :
  - $LOG/error.log
  - $LOG/ipmitool.log

Ce message a été envoyé automatiquement par : /var/ipmi/regul-vitesse-ventilo.sh
Utilisateur exécutant : $(whoami)
"

    {
        echo "From: $DE"
        echo "To: $A"
        echo "Subject: [ALERTE] Erreur dans la gestion des ventilateurs"
        echo "MIME-Version: 1.0"
        echo "Content-Type: text/plain; charset=\"utf-8\""
        echo ""
        echo "$BODY"
    } | "$SENDMAIL" -t
fi