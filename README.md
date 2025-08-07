# regul-vitesse-ventilo-SrvDell

**Un script shell pour la régulation automatique des ventilateurs sur serveurs Dell via IPMI.**  
Conçu pour les environnements silencieux comme une salle de classe, ce script ajuste dynamiquement la vitesse des ventilateurs en fonction des températures internes du serveur Dell PowerEdge (testé sur R920). Il vise à réduire le bruit sans compromettre la sécurité thermique.

---

## Table des matières

- [Fonctionnalités](#fonctionnalités)
- [Matériel concerné](#matériel-concerné)
- [Dépendances (Debian / Proxmox)](#dépendances-debian--proxmox)
- [Installation](#installation)
    - [1. Cloner ce dépôt](#1-cloner-ce-dépôt)
    - [2. Copier le script dans un répertoire système](#2-copier-le-script-dans-un-répertoire-système)
    - [3. Configurer le script](#3-configurer-le-script)
- [Activation du mode manuel](#activation-du-mode-manuel)
- [Utilisation](#utilisation)
    - [1. Exécution manuelle](#1-exécution-manuelle)
    - [2. Exécution via cron (toutes les minutes)](#2-exécution-via-cron-toutes-les-minutes)
    - [3. Ou en tant que service systemd](#3-ou-en-tant-que-service-systemd)
- [Script ventilo-mode.sh](#script-ventilo-modesh)
- [Test à blanc (sans modification)](#test-à-blanc-sans-modification)
- [Seuils de régulation (script principal)](#seuils-de-régulation-script-principal)
- [Structure des logs](#structure-des-logs)
- [Résultat final](#résultat-final)
- [Notes importantes](#notes-importantes)
- [Avertissement](#avertissement)
- [Licence](#licence)


---

## Fonctionnalités

- Régulation automatique de la vitesse des ventilateurs selon la température maximale détectée
- Intégration IPMI avec iDRAC (Dell)
- Enregistrement détaillé des actions et erreurs dans des fichiers de log
- Alerte par email en cas d'anomalie ou d'erreur d'exécution
- Mode test à blanc (sans envoi IPMI)
- Compatible `cron` ou `systemd`

---

## Matériel concerné
- Serveur Dell PowerEdge R920
- IDRAC7 version: 2.65.65.65
- IPMI activé et configuré (interface distante BMC)
- Adresse IP BMC utilisée : IP de IDRAC 
- Accès administrateur/utilisateur IPMI : utilisateur, mot de passe

---

## Dépendances (Debian / Proxmox)

Installez les dépendances nécessaires avec :

```bash
sudo apt update
sudo apt install ipmitool bc mailutils
```

---

## Installation
### 1. Cloner ce dépôt
```bash
git clone https://github.com/Ciel-Hazparne/regul-vitesse-ventilo-SrvDell.git
cd regul-vitesse-ventilo-SrvDell
```
### 2. Copier le script dans un répertoire système
```bash
sudo mkdir -p /var/ipmi
sudo cp regul-vitesse-ventilo.sh /var/ipmi/
sudo chmod +x /var/ipmi/regul-vitesse-ventilo.sh
```
### 3. Configurer le script
Éditez `/var/ipmi/regul-vitesse-ventilo.sh` :
```bash
IP="IP_IDRAC"
USER="utilisateur"
password="mot_de_passe_idrac"
DE="votre.mail@info.eh"
A="votre.mail@info.eh"
```

---

## Activation du mode manuel
Avant toute régulation, vous devez désactiver le contrôle automatique de l’iDRAC sur les ventilateurs avec :
```bash
sudo /usr/local/bin/ventilo-mode.sh start
```
Ce script active le mode « manuel IPMI ». Il doit être relancé à chaque redémarrage du serveur.  
Pour revenir au mode automatique :
```bash
sudo /usr/local/bin/ventilo-mode.sh stop
```

---

## Utilisation
### 1. Exécution manuelle
```bash
sudo /var/ipmi/regul-vitesse-ventilo.sh
```
### 2. Exécution via cron (toutes les minutes)
```bash
*/1 * * * * /var/ipmi/regul-vitesse-ventilo.sh > /dev/null 2>&1
```

### 3. Ou en tant que service systemd
#### ventilo-mode.service :
Fichier : `/etc/systemd/system/ventilo-mode.service`

```bash
[Unit]
Description=Active le contrôle manuel des ventilateurs IPMI
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ventilo-mode.sh start
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```
Activez le service :
```bash
sudo systemctl enable ventilo-mode.service
sudo systemctl start ventilo-mode.service
```

---

## Script ventilo-mode.sh
Fichier : `/usr/local/bin/ventilo-mode.sh`

```bash
GNU nano 7.2 
#!/bin/bash

# Configuration IPMI
IPMI_HOST="IP IDRAC"
IPMI_USER="utilisateur"
IPMI_PASS="mot_de_passe"

# Vérifier que ipmitool est installé
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
```

---

## Test à blanc (sans modification)

### Test régulation
Fichier : `/var/ipmi/test-regul-simulation.sh`

Affiche la température maximale détectée et la vitesse suggérée, sans rien exécuter ni modifier.
```bash
#!/bin/bash

IP="IP IDRAC"
USER="utilisateur"
PASS="mot_de_passe"

# Lire toutes les températures
temps=$(ipmitool -I lanplus -H $IP -U $USER -P $PASS sdr type Temperature | grep -E 'Inlet|Exhaust|Temp' | awk -F'|' '{ print $5 }' | grep -oE '[0-9]+')

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
```
### test pour mesurer la relation entre PWM (%) et vitesse RPM réelle
Fichier bash : `/var/ipmi/test_pwm_rpm.sh`  
Export : `/var/ipmi/test_pwm_rpm.log`  
On peut exécuter un script Python pour visualiser graphiquemnt l'évolution de la vitesse des ventilateurs.  
Export dans une image pwm_vs_rpm.png.  
Fichier : `/var/ipmi/plot_pwm_vs_rpm.py`
---

## Seuils de régulation (script principal)
Le script règle les ventilateurs selon la température maximale mesurée parmi les capteurs internes :
```bash
if   [ "$TEMP_MAX" -ge 70 ]; then NEWFANS=100
elif [ "$TEMP_MAX" -ge 60 ]; then NEWFANS=80
elif [ "$TEMP_MAX" -ge 50 ]; then NEWFANS=50
elif [ "$TEMP_MAX" -ge 45 ]; then NEWFANS=30
elif [ "$TEMP_MAX" -ge 35 ]; then NEWFANS=20
else                              NEWFANS=10
fi
```
### Température typique en salle au moment des tests :
    Inlet : ~25°C
    CPU : ~41°C
    Exhaust : ~36°C
    → Réglage typique des ventilateurs : 20–30%

---

## Structure des logs

    /var/log/ipmi/ipmitool.log → Journal d’exécution normal
    /var/log/ipmi/error.log → Journal des erreurs et alertes

---

## Résultat final
- Température CPU maintenue entre 40 et 43°C
- Bruit considérablement réduit (ventilateurs à 10–20%)
- Compatible usage en salle de classe
- Mode manuel activé automatiquement via ventilo-mode.service
- Sécurité : relance à 100% en cas d’anomalie

---

## Notes importantes
- Ce script désactive la gestion automatique des ventilateurs par l’iDRAC. Vous en prenez le contrôle manuel via IPMI. 
- Testé sur Dell R920, à venir sur R710. 
- En cas d'arrêt du script ou de valeurs incohérentes, la vitesse est automatiquement fixée à 100% pour éviter la surchauffe.

---

## Avertissement
Ce script est fourni "en l’état", sans aucune garantie.  
L'utilisateur assume l'entière responsabilité de son usage.  
Bien que testé avec succès sur un serveur Dell PowerEdge R920, l’auteur ne saurait être tenu responsable d’éventuels dysfonctionnements matériels, surchauffes, pertes de données ou dommages liés à l’utilisation de ce script.  
Utilisez-le avec précaution, après avoir vérifié sa compatibilité avec votre matériel.

---

## Licence
Ce projet est distribué sous licence MIT.