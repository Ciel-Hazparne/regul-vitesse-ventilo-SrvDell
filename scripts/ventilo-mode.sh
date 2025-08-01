#!/bin/bash

# Configuration IPMI
IPMI_HOST="IP IDRAC"
IPMI_USER="utilisateur"
IPMI_PASS="mot_de_passe"

# Vérifie que ipmitool est installé
command -v ipmitool >/dev/null 2>&1 || { echo >&2 "ipmitool est requis."; exit 1; }

function start() {
  echo "Passage en mode MANUEL..."
  ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" raw 0x30 0x30 0x01 0x00
  echo "Contrôle manuel activé. (IPMI)"
}

function stop() {
  echo "Retour en mode AUTOMATIQUE (BIOS)..."
  ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" raw 0x30 0x30 0x01 0x01
  echo "Contrôle automatique réactivé. (BIOS/IDRAC)"
}

function status() {
  echo "Lecture de l'état de contrôle (manuel / auto)..."
  # Ce status n’est pas directement lisible par une commande IPMI standard,
  # donc on envoie une vitesse pour tester (0% n'est pas dangereux).
  ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" raw 0x30 0x30 0x02 0xff 0x00 >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "Mode MANUEL actif (réglage manuel accepté)."
  else
    echo "Mode AUTOMATIQUE actif (réglage refusé par le BIOS)."
  fi
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    exit 1
esac
