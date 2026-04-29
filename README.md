# Nabaztag Piper — TTS local + Firmware

## Architecture

```
┌──────────────────────────────────────┐
│   Nabaztag v2                        │
│   (firmware custom)                  │
│                                      │
│   /say?t=... ──▶ HTTP :6790          │
│   bc.jsp       ◀── HTTP :80          │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│         Proxy TTS (port 6790)         │
│   piper_tts_stream.py                │
│                                      │
│   TTS_ENGINE=piper → Piper subproc   │
│   TTS_ENGINE=coqui → Coqui subproc   │
│                                      │
│   FFmpeg pipeline commun :           │
│     highpass=f=300, treble=g=3       │
│     resample 22050→16000 Hz          │
│     WAV s16le mono → Nabaztag        │
└──────────────────┬───────────────────┘
                   │
    ┌──────────────┴──────────────┐
    │                              │
┌───▼────────────┐    ┌───────────▼────┐
│ voices/piper/   │    │ .venv/ (Coqui) │
│ .onnx + .json   │    │ VITS français  │
└─────────────────┘    └────────────────┘
```

## Quick start

```bash
# Cloner
git clone https://github.com/jsapede/nabaztag-piper.git
cd nabaztag-piper/install

# Configurer
cp .env.example /opt/nabaztag-piper/.env
vi /opt/nabaztag-piper/.env   # éditer GLOBAL_DIR, TTS_ENGINE...

# Installer (--dry-run pour simuler)
./install.sh                  # installation complète
./install.sh --dry-run        # simulation

# Désinstaller
./install.sh --uninstall

# Tester
curl http://localhost:6790/say?t=Bonjour -o test.wav
file test.wav                 # → RIFF WAVE 16000 Hz
```

## Installation détaillée

### Prérequis

- Ubuntu/Debian (testé sur 24.04)
- Python ≥ 3.10
- 6GB RAM libre (pour Coqui : 600MB)
- Connexion internet (téléchargement des modèles)

### Le script `install.sh` fait tout automatiquement

| # | Étape | Selon .env |
|---|-------|-----------|
| 1 | Crée le dossier global | GLOBAL_DIR |
| 2 | Copie les fichiers proxy | — |
| 3 | Installe espeak-ng, ffmpeg, build-essential, make, uv | — |
| 4 | pip install piper-tts | — |
| 5 | Télécharge la voix Piper (.onnx) | PIPER_VOICE_PATH |
| 6 | Installe Coqui (venv + PyTorch CPU) | TTS_ENGINE=coqui |
| 7 | Compile le firmware | BUILD_FIRMWARE=true |
| 8 | Installe static-web-server | ENABLE_WEB_SERVER=true |
| 9 | Crée le service nabaztag-tts | — |
| 10 | Crée le service nabaztag-webserver | ENABLE_WEB_SERVER=true |

### Configuration (.env)

```bash
GLOBAL_DIR=/opt/nabaztag-piper       # dossier d'exécution
TTS_ENGINE=piper                     # piper | coqui
TTS_PORT=6790
PIPER_VOICE_PATH=fr/fr_FR/siwis/medium
BUILD_FIRMWARE=true                  # compiler le firmware
ENABLE_WEB_SERVER=true               # servir le firmware
WEB_SERVER_PORT=80
```

### Changer la voix Piper

```bash
# 1. Écouter les voix : https://rhasspy.github.io/piper-samples/
# 2. Explorer les modèles : https://huggingface.co/rhasspy/piper-voices/tree/main
# 3. Modifier .env
PIPER_VOICE_PATH=fr/fr_FR/gilles/low  # voix masculine française
# 4. Relancer install.sh (détecte les changements)
./install.sh
```

## Services systemd

| Service | Rôle | Port |
|---------|------|------|
| `nabaztag-tts` | Proxy TTS (Piper ou Coqui) | 6790 |
| `nabaztag-webserver` | Serveur web firmware | 80 |

```bash
systemctl status nabaztag-tts
journalctl -u nabaztag-tts -f
journalctl -u nabaztag-webserver -f
```

## Firmware

Le firmware Nabaztag est dans `vl/` (Forth) et `firmware/` (MTL). Compilation :

```bash
make compiler      # compiler le compilateur MTL
make firmware      # compiler le firmware → vl/bc.jsp
```

Le firmware compile avec **0 erreur**. Endpoints principaux :

| Endpoint | Description |
|----------|-------------|
| `/autocontrol?c=0/1&h=0/1&s=0/1&t=0/1` | 4 flags firmware |
| `/autostatus` | JSON des flags |
| `/say?t=texte` | TTS |
| `/forth?c=code` | Interpréteur Forth |
| `/setup?j=&k=&l=...` | Configuration |

## Home Assistant

Le dossier `homeassistant/` contient la configuration complète à intégrer dans Home Assistant :

```yaml
# Dans configuration.yaml de Home Assistant (ou packages/)
homeassistant:
  packages:
    nabaztag: !include_dir_named ../path/to/nabaztag-piper/homeassistant/nabaztag
    nabaztag_lovelace: !include_dir_named ../path/to/nabaztag-piper/homeassistant/lovelace
```

Ou copier le dossier `homeassistant/nabaztag/` dans votre dossier `packages/` :

```bash
cp -r homeassistant/nabaztag /config/packages/
# puis dans configuration.yaml :
homeassistant:
  packages: !include_dir_named packages
```

```bash
homeassistant/
├── nabaztag/                    ← Config HA (automations, scripts, commands...)
│   ├── nabaztag_automations.yaml
│   ├── nabaztag_scripts.yaml
│   ├── nabaztag_commands.yaml
│   ├── nabaztag_inputs.yaml
│   ├── nabaztag_life.yaml
│   └── nabaztag_sensors.yaml
├── lovelace/                    ← Cartes du dashboard
│   ├── nabaztag_lovelace.yaml
│   ├── nabaztag_lovelace_config.yaml
│   └── nabaztag_led_guide.yaml
└── docs/                        ← Documentation détaillée
    ├── AUTOMATIONS.md           ← Guide des automations
    ├── SCRIPTS.md               ← Guide des scripts
    ├── REST_COMMANDS.md         ← Guide des commandes REST
    ├── INPUTS.md                ← Guide des helpers/inputs
    ├── NABAZTAG_LIFE.md         ← Guide du module Life
    └── SOUNDS_GUIDE.md          ← Guide des sons et animations
```

## Structure du projet

```
nabaztag-piper/
├── install/
│   ├── install.sh              ← installateur unifié
│   ├── piper_tts_stream.py     ← proxy TTS
│   ├── coqui_cli.py            ← CLI Coqui
│   └── .env.example            ← template .env
├── vl/                         ← sources Forth du firmware
├── firmware/                   ← sources MTL
├── homeassistant/              ← configuration HA
├── Makefile
├── CHANGELOG.md
└── README.md
```

## Dépôt GitHub

```
https://github.com/jsapede/nabaztag-piper
→ Fork de andreax79/ServerlessNabaztag
```

Voir `CHANGELOG.md` pour l'historique complet.
