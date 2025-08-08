# regul-vitesse-ventilo-SrvDell

**Un script shell pour la régulation automatique des ventilateurs sur serveurs Dell via IPMI.**  
Conçu pour les environnements silencieux comme une salle de classe, ce script ajuste dynamiquement la vitesse des ventilateurs en fonction des températures internes du serveur Dell PowerEdge (testé sur R920). Il vise à réduire le bruit sans compromettre la sécurité thermique.

---

## Table des matières
<!-- TOC -->
* [regul-vitesse-ventilo-SrvDell](#regul-vitesse-ventilo-srvdell)
  * [Table des matières](#table-des-matières)
  * [Fonctionnalités](#fonctionnalités)
  * [Matériel concerné](#matériel-concerné)
  * [Dépendances (Debian / Proxmox)](#dépendances-debian--proxmox)
  * [Installation](#installation)
    * [1. Cloner ce dépôt](#1-cloner-ce-dépôt)
    * [2. Copier le script dans un répertoire système](#2-copier-le-script-dans-un-répertoire-système)
    * [3. Configurer le script](#3-configurer-le-script)
  * [Activation du mode manuel](#activation-du-mode-manuel)
  * [Utilisation](#utilisation)
    * [1. Exécution manuelle](#1-exécution-manuelle)
    * [2. Exécution via cron (toutes les minutes)](#2-exécution-via-cron-toutes-les-minutes)
    * [3. Ou en tant que service systemd](#3-ou-en-tant-que-service-systemd)
      * [ventilo-mode.service :](#ventilo-modeservice-)
  * [Script ventilo-mode.sh](#script-ventilo-modesh)
  * [Script regul-vitesse-ventilo.sh](#script-regul-vitesse-ventilosh)
  * [Test à blanc (sans modification)](#test-à-blanc-sans-modification)
    * [Test régulation](#test-régulation)
    * [Test pour mesurer la relation entre PWM (%) et vitesse RPM réelle](#test-pour-mesurer-la-relation-entre-pwm--et-vitesse-rpm-réelle)
  * [Seuils de régulation (script principal)](#seuils-de-régulation-script-principal)
    * [Température typique en salle au moment des tests :](#température-typique-en-salle-au-moment-des-tests-)
  * [Structure des logs](#structure-des-logs)
  * [Résultat final](#résultat-final)
  * [Actions et commandes utiles](#actions-et-commandes-utiles)
    * [IDRAC 7](#idrac-7)
    * [systemd](#systemd)
    * [IPMI](#ipmi)
      * [Vérification de la communication :](#vérification-de-la-communication--)
      * [Relever la vitesse des ventilateurs](#relever-la-vitesse-des-ventilateurs)
      * [Tester manuellement  la prise en compte de la consigne de vitesse](#tester-manuellement--la-prise-en-compte-de-la-consigne-de-vitesse)
  * [Notes importantes](#notes-importantes)
  * [Avertissement](#avertissement)
  * [Licence](#licence)
<!-- TOC -->

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
Activer le service :
```bash
sudo systemctl enable ventilo-mode.service
sudo systemctl start ventilo-mode.service
```

---

## Script ventilo-mode.sh
Ce script permet de basculer entre les modes de contrôle manuel et automatique des ventilateurs du serveur
via IPMI, et de vérifier l'état actuel du mode de contrôle.
Voici un aperçu des fonctionnalités :
1. **Configuration IPMI** : Le script commence par définir les variables nécessaires pour se connecter à 
l'interface IPMI, telles que l'adresse hôte, le nom d'utilisateur et le mot de passe. 
2. **Vérification de ipmitool** : Avant de continuer, le script vérifie si l'outil ipmitool est installé sur
le système. Cet outil est essentiel pour envoyer des commandes IPMI. 
3. **Fonctions principales** :
   - **start** : Cette fonction passe le contrôle des ventilateurs en mode manuel. Cela permet à l'utilisateur
   ou à systemd de définir manuellement la vitesse des ventilateurs.
   - **stop** : Cette fonction réactive le mode automatique, permettant au BIOS ou à l'iDRAC de contrôler
   automatiquement la vitesse des ventilateurs.
   - **status** : Cette fonction vérifie l'état actuel du contrôle des ventilateurs. Elle envoie une commande
   de test pour déterminer si le système est en mode manuel ou automatique.
4. **Gestion des arguments** : Le script utilise une instruction case pour gérer les arguments passés par
l'utilisateur. Selon l'argument fourni (start, stop, ou status), la fonction correspondante est appelée.
5. **Usage** : Si aucun argument valide n'est fourni, le script affiche un message d'usage indiquant comment
l'utiliser correctement.

Fichier : `/usr/local/bin/ventilo-mode.sh`


---

## Script regul-vitesse-ventilo.sh
Ce script automatise la surveillance et le contrôle des ventilateurs d'un serveur en fonction des températures
mesurées, assurant ainsi un refroidissement optimal et une gestion proactive des erreurs.
Voici un aperçu des fonctionnalités :
1. **Configuration initiale** :
   - Le script commence par définir le fuseau horaire à "Europe/Paris". 
   - Il configure les paramètres de connexion IPMI, tels que l'adresse IP, le nom d'utilisateur et le mot de passe. 
   - Il crée un dossier de logs pour enregistrer les activités et les erreurs.

2. **Gestion des logs et des alertes** :
   - Les logs sont enregistrés dans /var/log/ipmi avec des fichiers séparés pour les erreurs et les activités normales. 
   - En cas d'erreur, un email d'alerte est envoyé à une adresse spécifiée, contenant les derniers messages d'erreur et les fichiers de log à consulter.
3. **Lecture des températures** :
   - Le script utilise `ipmitool` pour lire les températures des capteurs.
   - Il extrait les valeurs numériques des températures et détermine la température maximale.
4. **Régulation de la vitesse des ventilateurs** :
   - En fonction de la température maximale détectée, le script ajuste la vitesse des ventilateurs :
     - 100% si la température est ≥ 70°C 
     - 80% si la température est ≥ 60°C 
     - 30% si la température est ≥ 50°C 
     - 20% si la température est ≥ 45°C 
     - 15% si la température est ≥ 35°C 
     - 10% sinon  
   **Note** : ces seuils seront peut-être modifiés en fonction du retour des usagers et des températures des CPU.
5. **Activation du mode manuel et envoi de la consigne** :
   - Le script active le mode manuel pour le contrôle des ventilateurs. 
   - Il convertit la vitesse des ventilateurs en hexadécimal et envoie la consigne via IPMI.
6. Gestion des erreurs :
   - Si des erreurs surviennent lors de la lecture des capteurs ou de l'envoi des commandes IPMI, elles sont
   enregistrées dans le fichier de log des erreurs. 
   - En cas d'erreur, un email d'alerte est envoyé avec les détails des erreurs rencontrées.

## Test à blanc (sans modification)

### Test régulation
Affiche la température maximale détectée et la vitesse suggérée,
sans rien exécuter ni modifier.  
- Fichier : `/var/ipmi/test-regul-simulation.sh`

### Test pour mesurer la relation entre PWM (%) et vitesse RPM réelle
- Fichier bash : `/var/ipmi/test_pwm_rpm.sh`  
- Export : `/var/ipmi/test_pwm_rpm.log`  
On peut exécuter un script Python pour visualiser graphiquemnt l'évolution de la vitesse des ventilateurs.  
  - Export dans une image pwm_vs_rpm.png.  
  - Fichier : `/var/ipmi/plot_pwm_vs_rpm.py`
---

## Seuils de régulation (script principal)
Le script règle les ventilateurs selon la température maximale mesurée parmi les capteurs internes :
```bash
if   [ "$TEMP_MAX" -ge 70 ]; then NEWFANS=100
elif [ "$TEMP_MAX" -ge 60 ]; then NEWFANS=80
elif [ "$TEMP_MAX" -ge 50 ]; then NEWFANS=30 # 3900 rpm
elif [ "$TEMP_MAX" -ge 45 ]; then NEWFANS=20 # 3000 rpm
elif [ "$TEMP_MAX" -ge 35 ]; then NEWFANS=15 # 2640 rpm
else                              NEWFANS=10 # 2040 rpm
fi
```
### Température typique en salle au moment des tests :
    Inlet : ~25°C
    CPU : ~41°C
    Exhaust : ~36°C
    → Réglage typique des ventilateurs : 15%

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

## Actions et commandes utiles
### IDRAC 7
* Activer IPMI sur le réseau :  
`Paramètres d'IDRAC > Réseau > Paramètres IPMI > Activer IPMI sur le LAN`  
* Redémarrer IDRAC :  
`racadm racreset`
### systemd
* Verifier que le servcie est lancé :  
`systemctl status ventilo-mode.service`

### IPMI
#### Vérification de la communication :  
`ipmitool -I lanplus -H IP_IDRAC -U utilisateur -P 'mot_de_passe' sdr type "Temperature"`  
Exemple de réponse :  

| Nom du capteur  | Id hexa | Statut | Val num | Température |
|--------------|---------|----|---------|-------------|
| Inlet Temp   | 04h     | ok | 7.1     | 27 degrees C |
| Exhaust Temp | 01h     | ok | 7.1     | 41 degrees C |
| Temp         | 09h     | ok | 7.1     | 45 degrees C |
| Temp         | 06h     | ok | 7.1     | 40 degrees C |
| Temp         | 07h     | ok | 7.1     | 38 degrees C |
| Temp         | 08h     | ok | 7.1     | 39 degrees C |
1. **Nom du capteur** : nom ou description du capteur de température. 
Par exemple, "Inlet Temp" et "Exhaust Temp" indiquent respectivement les températures 
d'entrée et de sortie de l'air.
2. **Identifiant hexadécimal** : chaque capteur a un identifiant unique, souvent 
représenté en hexadécimal (par exemple, 75h, 2Ch). Cela permet de distinguer les différents
capteurs et composants dans le système. 
3. **Statut** : Indique l'état du capteur. Les valeurs possibles
incluent :
   - **ok** : le capteur fonctionne correctement.
   - **ns** : non spécifié ou non applicable. 
   - D'autres valeurs peuvent indiquer des états spécifiques comme des erreurs ou des avertissements.
4. **Valeur numérique** (7.1, 3.1, 3.2, etc.) : valeur spécifique non utile ici. 
5. **Température** (27 degrees C, etc) : lecture de température réelle en degrés Celsius. 
C'est la valeur principale à surveiller pour s'assurer que le matériel fonctionne à une température sûre.

#### Relever la vitesse des ventilateurs
`ipmitool sdr type Fan`  
```bash
Fan1             | 30h | ok  |  7.1 | 3000 RPM  
Fan2             | 31h | ok  |  7.1 | 3000 RPM  
Fan3             | 32h | ok  |  7.1 | 3000 RPM  
Fan4             | 33h | ok  |  7.1 | 3000 RPM  
Fan5             | 34h | ok  |  7.1 | 3000 RPM  
Fan6             | 35h | ok  |  7.1 | 3000 RPM  
Fan Redundancy   | 75h | ok  |  7.1 | Fully Redundant
```
#### Tester manuellement  la prise en compte de la consigne de vitesse
* Envoyer une commande de PWM à 10% (0x0a) :  
`ipmitool -I lanplus -H IP_IDRAC -U utilisateur -P 'mot_de_passe' raw 0x30 0x30 0x02 0xff 0x0a`  
* Verifier la vitesse des ventilateurs (vu au-dessus) :  
`ipmitool sdr type Fan`
* Verifier l'état des capteurs :  
`ipmitool sensor`
* Obtenir des informations sur le système :  
`ipmitool mc info`

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