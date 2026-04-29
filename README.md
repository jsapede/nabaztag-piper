# Nabaztag Serverless - TTS Local avec Piper et Coqui

## Préambule important

### IP utilisées (à adapter)

Les adresses IP utilisées dans ce projet sont des **exemples** et doivent être ajustées à votre configuration réseau:

- `192.168.0.42` (ou `192.168.0.35`) - Adresse IP du serveur TTS (où tourne le proxy Python)
- `192.168.0.58` - Adresse IP du Nabaztag (optionnel, pour info)

**⚠️ L'IP du serveur Python est definie dans `vl/config.forth` et remplacee automatiquement par `install.sh` via la variable `TTS_SERVER_IP` du `.env`.**

Plus besoin de modifier les fichiers source manuellement.

---

## Architecture

```
┌─────────────────┐       ┌──────────────────┐       ┌─────────────────┐
│   Nabaztag v2   │       │   Serveur TTS    │       │  Piper / Coqui  │
│  192.168.0.58   │──────▶│  192.168.0.42    │──────▶│  TTS neuronal   │
│                 │  HTTP │    :6790         │       │   (22kHz WAV)  │
│  say "texte"    │       │                  │       │                 │
└─────────────────┘       └────────┬─────────┘       └─────────────────┘
                                    │
                            ┌───────▼─────────┐
                            │     FFmpeg     │
                            │  16kHz + filtres│
                            │  + header WAV  │
                            └─────────────────┘
```

---

## Présentation

Ce projet remplace le système TTS Google Translate du Nabaztag par un moteur de synthèse vocale local utilisant **Piper** (TTS neuronal) avec traitement audio **FFmpeg**.

L'objectif est d'obtenir une voix française naturelle et de qualité sans dépendance externe, avec un démarrage rapide du Nabaztag.

Ce dépôt (`nab-piper/`) contient les **fichiers sources modifiés** par rapport au firmware d'origine `andreax79/ServerlessNabaztag`.

---

## Fichiers modifiés par rapport au firmware d'origine

### Firmware (MTL)

| Fichier | Modification |
|---------|-------------|
| `firmware/net/ntp.mtl` | **Bug fix critique**: Correction du calcul NTP (soustraction incorrecte de l'uptime) |
| `firmware/srv/http_server.mtl` | Bug fixes: double point-virgule manquant, paramètre `list` → `wlist` |
| `firmware/protos/ntp_protos.mtl` | Serveur NTP à IP fixe (`216.239.35.12`) |
| `firmware/audio/audiolib.mtl` | Buffers: 64KB start, 512KB max |
| `firmware/utils/config.mtl` | Langue française par défaut si non configurée |
| `firmware/utils/url.mtl` | Fonctions `url_encode`/`url_decode` |

### Forth (vl/)

| Fichier | Modification |
|---------|-------------|
| `vl/config.forth` | 4 variables auto-control + authentification |
| `vl/hooks.forth` | Vérification drapeaux clock/halftime + say redirigé vers Piper |
| `vl/crontab.forth` | Vérification drapeaux surprise/taichi |
| `vl/words.txt` | Liste des mots Forth |

---

## Fonctionnalités

### Proxy TTS (`piper_tts_stream.py`)

- **Synthèse vocale**: Piper avec voix française (fr_FR-siwis-medium)
- **Resampling**: Conversion 22kHz → 16kHz (compatible Nabaztag)
- **Filtres audio FFmpeg**:
  - `highpass=f=300` - Supprime les basses fréquences
  - `treble=g+3` - Amplifie les aigus pour la clarté vocale
  - `volume=1.5` - Augmente le volume global
- **Phonèmes optionnels**: Conversion texte → phonèmes IPA via espeak-ng
- **Header WAV manuel**: Résout les problèmes de streaming FFmpeg

### Options CLI

```bash
# Défaut: Piper + FFmpeg + filtres
python piper_tts_stream.py

# Avec phonèmes (meilleure prononciation)
python piper_tts_stream.py --phonemes

# Piper seul (pas de transcoding)
python piper_tts_stream.py --no-ffmpeg

# FFmpeg resampling seulement (pas de filtres)
python piper_tts_stream.py --no-filters
```

### Variables d'environnement

Voir le fichier `.env` pour toutes les options configurables.

---

## Guide de modification du firmware

Ce guide explique comment modifier le firmware d'origine et le recompiler avec les changements de ce projet.

### Prérequis

```bash
# Installer les dépendances de compilation
apt install build-essential git

# Le serveur Python Piper doit tourner sur une machine accessible par le Nabaztag
# Voir la section "Installation du proxy TTS"
```

### Étapes

#### 1. Cloner le dépôt d'origine

```bash
git clone https://github.com/andreax79/ServerlessNabaztag.git ServerlessNabaztag
cd ServerlessNabaztag
```

#### 2. ⚠️ CHANGER l'IP du serveur Python (IMPORTANT!)

Avant de copier les fichiers, vous DEVEZ modifier l'adresse IP du serveur Python dans `vl/hooks.forth`:

```bash
# Éditer vl/hooks.forth et changer ligne 43:
# Ancienne ligne:
nil "http://192.168.0.42:6790/say?t=" :: r> :: str-join

# Nouvelle ligne (adapter l'IP à votre configuration):
nil "http://192.168.1.100:6790/say?t=" :: r> :: str-join
```

Cette IP doit être celle où le serveur Python Piper va tourner (accessible par le Nabaztag).

#### 3. Copier les fichiers modifiés

```bash
#Copier tous les fichiers modifiés depuis nab-piper/
cp ../nab-piper/vl/config.forth vl/
cp ../nab-piper/vl/hooks.forth vl/
cp ../nab-piper/vl/crontab.forth vl/
cp ../nab-piper/vl/words.txt vl/

cp ../nab-piper/firmware/audio/audiolib.mtl firmware/audio/
cp ../nab-piper/firmware/utils/url.mtl firmware/utils/
cp ../nab-piper/firmware/utils/config.mtl firmware/utils/
cp ../nab-piper/firmware/protos/ntp_protos.mtl firmware/protos/
cp ../nab-piper/firmware/net/ntp.mtl firmware/net/
cp ../nab-piper/firmware/srv/http_server.mtl firmware/srv/
```

#### 4. Compiler le firmware

```bash
# Compiler le compilateur
make compiler

# Compiler le firmware
make firmware
```

Le fichier `vl/bc.jsp` est généré (bytecode du firmware).

#### 5. Préparer le serveur web

Le Nabaztag télécharge son firmware au démarrage depuis un serveur web statique.

```bash
#Servir le dossier vl/ sur le port 80
cd vl/
python3 -m http.server 80
```

#### 6. Démarrer le serveur Python Piper

```bash
#Sur une machine accessible par le Nabaztag (même IP que dans hooks.forth)
python3 piper_tts_stream.py
```

#### 7. Démarrer le Nabaztag

Au démarrage, le Nabaztag demande `vl/bc.jsp` depuis:
- Son URL de configuration (paramètre `u=` dans `/config/` ou via DHCP)
- Ou `http://default/vl/bc.jsp` en fallback

Le nouveau firmware est téléchargé et démarré automatiquement.

---

## Installation du proxy TTS

### Prérequis serveur

```bash
# Debian/Ubuntu
apt install ffmpeg espeak-ng python3-pip

# Installer Piper (voir https://github.com/OHF-Voice/piper1-gpl)
# Voix disponibles: fr_FR-siwis-medium, fr_FR-tom-medium
```

### Déploiement

```bash
# Copier les fichiers du proxy
cp piper_tts_stream.py /opt/nabaztag/
cp .env /opt/nabaztag/

# Installer le service systemd
cp piper-tts.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable piper-tts
systemctl start piper-tts
```

---

## Contrôle des automatismes du Nabaztag

Le firmware modifié inclut 4 drapeaux pour contrôler les comportements automatiques:

| Variable | Description | Default |
|----------|-------------|---------|
| `autoclock-enabled` | Annonces horaires (heure pile) | 1 (ON) |
| `autohalftime-enabled` | Annonces demi-heures | 1 (ON) |
| `autosurprise-enabled` | Sons surprise | 1 (ON) |
| `autotaichi-enabled` | Mouvements taichi | 1 (ON) |

### Contrôle depuis Home Assistant

Le Nabaztag peut être contrôlé via l'endpoint `/forth` depuis Home Assistant:

```bash
# Désactiver les automatiques
curl "http://nabaztag.local/forth?c=0%20autoclock-enabled%20%21"

# Activer les automatiques
curl "http://nabaztag.local/forth?c=1%20autoclock-enabled%20%21"
```

Le Nabaztag expose également 4 input_booleans dans Home Assistant pour un contrôle graphique:
- `input_boolean.firmware_clock`
- `input_boolean.firmware_halftime`
- `input_boolean.firmware_surprise`
- `input_boolean.firmware_taichi`

---

## Dépannage

### Le Nabaztag ne parle pas

```bash
# Vérifier que le service est actif
systemctl status piper-tts

# Tester manuellement
curl "http://192.168.0.42:6790/say?t=bonjour" -o test.wav
file test.wav  # Devrait être: RIFF WAVE audio
```

### L'horloge a du retard ou avance

Ce problème a été corrigé dans la version actuelle du firmware. Si vous observez des dérives:
- Le serveur NTP peut être saturé ou victime de bloqueurs
- Le serveur `216.239.35.12` (Google) est fiable mais peut être bloqué par certains firewalls

### Le Nabaztag ne démarre pas avec le nouveau firmware

- Vérifier que le serveur web sert bien `vl/bc.jsp`
- Vérifier les logs: `journalctl -u piper-tts -f`

---

## Détails techniques

### Bug NTP corrigé (firmware/net/ntp.mtl)

Le code original soustrayait l'uptime (`now`) du timestamp NTP:

```mtl
// AVANT (buggé)
let time -> now in (
    set time_high = (strgetword msg 40) - (now >> 16);
    set time_low = (strgetword msg 42) - (now % 65536)
);
```

Cette erreur causait une dérive progressive: au reboot, `now` ≈ 0, mais au fil du temps, la soustraction augmentait, donc l'heure announced arrivait de plus en plus tôt.

```mtl
// APRÈS (corrigé)
set time_high = strgetword msg 40;
set time_low = strgetword msg 42;
```

### Buffers audio (firmware/audio/audiolib.mtl)

| Constante | Valeur originale | Valeur modifiée |
|----------|----------------|----------------|
| `WAV_BUFFER_STARTSIZE` | 80000 | 64000 |
| `WAV_BUFFER_MAXSIZE` | 400000 | 512000 |

- **Start**: 64KB permet un démarrage plus rapide (~0.5s)
- **Max**: 512KB améliore la stabilité WiFi

### Commandes FFmpeg utilisées

```bash
ffmpeg -f wav -i - \
    -af highpass=f=300,treble=g=3,volume=1.5 \
    -ar 16000 -ac 1 -acodec pcm_s16le \
    -f s16le -
```

---

## Structure du projet

```
/opt/
├── ServerlessNabaztag/        # Dépôt cloné depuis github
│   ├── vl/                    # Fichiers Forth
│   ├── firmware/              # Code source MTL
│   ├── compiler/            # Compilateur
│   └── scripts/             # Scripts de compilation
│
└── nab-piper/               # Nos modifications (ce dépôt)
    ├── vl/
    │   ├── hooks.forth        # Fonction say redirigée vers TTS
    │   ├── config.forth     # Auto-control + auth
    │   ├── crontab.forth   # Vérification drapeaux
    │   └── words.txt      # Mots Forth
    ├── firmware/
    │   ├── audio/audiolib.mtl
    │   ├── net/ntp.mtl
    │   ├── protos/ntp_protos.mtl
    │   ├── srv/http_server.mtl
    │   └── utils/
    ├── scripts/
    ├── piper_tts_stream.py    # Proxy TTS
    ├── .env
    ├── piper-tts.service
    ├── README.md
    └── CHANGELOG.md
```

---

## Licence

Ce projet est basé sur [andreax79/ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag).

Piper est sous licence GPL - voir [OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl).