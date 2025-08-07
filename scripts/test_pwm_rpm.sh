#!/bin/bash

# Fichier de log
LOGFILE="/var/ipmi/pwm_rpm_test.log"

# Config IPMI
IP="IP_IDRAC"
USER="utilisateur"
PASSWORD="mot_de_passe"

# Palier de test
PWM_VALUES=(10 15 20 30 40)
PAUSE=30  # secondes à attendre entre chaque palier

# Initialisation du fichier log
echo "===== Test PWM -> RPM =====" | tee "$LOGFILE"
echo "Début : $(date)" | tee -a "$LOGFILE"
echo "Chaque palier dure $PAUSE secondes" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

for pwm in "${PWM_VALUES[@]}"; do
    echo "[$(date)] Envoi PWM = $pwm%" | tee -a "$LOGFILE"

    # Envoi de la commande IPMI (0x30 0x30 0x02 0xff <pwm en hexadécimal>)
    HEXPWM=$(printf '0x%02x' "$pwm")
    ipmitool -I lanplus -H "$IP" -U "$USER" -P "$PASSWORD" raw 0x30 0x30 0x02 0xff "$HEXPWM" \
        && echo "PWM $pwm% appliqué." | tee -a "$LOGFILE" \
        || echo "Échec de la commande PWM $pwm%" | tee -a "$LOGFILE"

    # Pause pour stabilisation
    sleep "$PAUSE"

    # Lecture RPM
    echo "Lecture des vitesses RPM" | tee -a "$LOGFILE"
    ipmitool -I lanplus -H "$IP" -U "$USER" -P "$PASSWORD" sdr type Fan \
        | tee -a "$LOGFILE"

    echo "" | tee -a "$LOGFILE"
done

echo "Fin du test : $(date)" | tee -a "$LOGFILE"
