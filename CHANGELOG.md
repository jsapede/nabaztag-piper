# Changelog - Nabaztag Serverless TTS

## 2026-04-29 - Version finale multi-TTS

### Architecture générale

Le proxy TTS (`piper_tts_stream.py`) supporte deux moteurs, configurés via `.env` :

```
TTS_ENGINE=piper  →  subprocess Piper → FFmpeg → WAV 16kHz → Nabaztag
TTS_ENGINE=coqui  →  subprocess Coqui → FFmpeg → WAV 16kHz → Nabaztag
                              (pipeline FFmpeg strictement identique)
```

Le projet utilise un dossier global (`GLOBAL_DIR` dans .env) séparé du repo source :

```
📂 Repo GitHub (cloné)
└── install/
    ├── install.sh              ← --dry-run, --uninstall, réinstall auto
    ├── piper_tts_stream.py     ← Proxy TTS (lit TTS_ENGINE du .env)
    ├── coqui_cli.py             ← CLI Coqui (stdin → WAV)
    └── .env.example

📂 GLOBAL_DIR (exécution)
├── .env                        ← Configuration unique
├── piper_tts_stream.py
├── coqui_cli.py
├── .venv/                      ← Venv Coqui
├── voices/piper/               ← Modèles .onnx Piper
└── firmware/vl/                ← Firmware compilé servi par le web
```

### Installateur unifié (`install/install.sh`)

| Option | Description |
|--------|-------------|
| `./install.sh` | Installation complète |
| `./install.sh --dry-run` | Simulation seule |
| `./install.sh --uninstall` | Désinstallation complète |

Étapes automatiques (10) :
1. Création du dossier global + sous-dossiers
2. Copie des fichiers du proxy
3. Installation des dépendances système (espeak-ng, ffmpeg, build-essential, make)
4. Installation Piper (`pip install piper-tts`)
5. Téléchargement de la voix Piper depuis HuggingFace
6. Installation Coqui (si TTS_ENGINE=coqui) : venv, PyTorch CPU, téléchargement VITS
7. Compilation du firmware si BUILD_FIRMWARE=true
8. Installation static-web-server pour servir le firmware
9. Service systemd nabaztag-tts
10. Service systemd nabaztag-webserver

### Serveur web firmware

- Utilise [static-web-server](https://static-web-server.net) (binaire Rust, 4MB)
- Sert les fichiers du firmware compilé sur le port configuré
- Permet au Nabaztag de télécharger son microcode au démarrage

### Nouveaux fichiers

| Fichier | Rôle |
|---------|------|
| `install/install.sh` | Installateur unifié avec --dry-run et --uninstall |
| `install/piper_tts_stream.py` | Proxy TTS (configuration via .env, plus de flags) |
| `install/coqui_cli.py` | Wrapper CLI Coqui (stdin → WAV, subprocess) |
| `install/.env.example` | Template de configuration |

### Fichiers supprimés

| Fichier | Remplacé par |
|---------|-------------|
| `install_coqui.sh` | `install/install.sh` |
| `piper-tts.service` | `nabaztag-tts.service` (généré par install.sh) |
| `systemd/*.service` | Obsolètes |
| Flags `--coqui`, `--phonemes` | Variables `.env` (TTS_ENGINE, PIPER_USE_PHONEMES) |

### Variables .env simplifiées

```bash
GLOBAL_DIR=/opt/nabaztag-piper
TTS_ENGINE=piper                    # piper | coqui
TTS_PORT=6790
PIPER_VOICE_PATH=fr/fr_FR/siwis/medium
BUILD_FIRMWARE=true                 # compiler le firmware
ENABLE_WEB_SERVER=true              # servir le firmware
WEB_SERVER_PORT=80
```

### Évolution des fonctionnalités

| Date | Changement |
|------|-----------|
| 2026-04-29 | **Multi-TTS** : Coqui VITS, installateur unifié, --uninstall, static-web-server |
| 2026-04-29 | Refactoring REST commands (20→2) + autostatus + sensors |
| 2026-04-29 | Service générique, TTS IP externalisée |
| 2026-04-18 | Auto-control firmware, bug fixes NTP/HTTP, compilation 0 erreur |
| 2024-04-15 | Architecture Piper TTS complète |
| 2024-04-14 | Version initiale Piper TTS |
