#!/bin/bash

IP="IP_IDRAC"
USER="utilisateur"
PASSWORD="mot_de_passe"

# Lire toutes les températures
temps=$(ipmitool -I lanplus -H $IP -U $USER -P $PASSWORD sdr type Temperature | grep -E 'Inlet|Exhaust|Temp' | awk -F'|' '{ print $5 }' | grep -oE '[0-9]+')

# Vérifier que l'on a bien des valeurs
if [ -z "$temps" ]; then
  echo "[ERREUR] Aucune température détectée."
  exit 1
fi

# Initialiser variables
fan_speed=20
temp_max=0

# Rechercher la température la plus élevée
for t in $temps; do
  if [ "$t" -gt "$temp_max" ]; then
    temp_max=$t
  fi
done

# Déterminer la vitesse des ventilateurs en fonction de la température max
if   [ "$temp_max" -ge 70 ]; then fan_speed=100
elif [ "$temp_max" -ge 60 ]; then fan_speed=80
elif [ "$temp_max" -ge 50 ]; then fan_speed=60
elif [ "$temp_max" -ge 45 ]; then fan_speed=40
elif [ "$temp_max" -ge 35 ]; then fan_speed=30
else fan_speed=20
fi

# Résumé (sans envoi)
echo "Température maximale détectée : ${temp_max}°C"
echo "Vitesse ventilateurs suggérée : ${fan_speed}%"
echo "(simulation : aucun envoi IPMI effectué)"