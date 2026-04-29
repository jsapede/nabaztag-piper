#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Nabaztag TTS — Installation unifiée
# Usage: ./install.sh /chemin/vers/le/projet [--dry-run]
#   Chemin = dossier racine du projet (ex: /opt/nabaztag-piper)
#   --dry-run = simule sans rien installer
# ═══════════════════════════════════════════════════════════════

set -e

DRY_RUN=false
if [ "$2" = "--dry-run" ] || [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo "═════ DRY RUN — aucune modification ═════"
fi

# Déterminer PROJECT_DIR
if [ -n "$1" ] && [ "$1" != "--dry-run" ]; then
    PROJECT_DIR="$(cd "$1" && pwd)"
else
    PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

echo "Projet: $PROJECT_DIR"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "ERREUR: $PROJECT_DIR/.env introuvable"
    echo "Copier .env.example vers .env et editer"
    exit 1
fi

source "$PROJECT_DIR/.env"

# ─── Helper dry-run ────────────────────────────────────────
run() {
    if [ "$DRY_RUN" = true ]; then
        echo "   ❯ $*"
    else
        echo "   ❯ $*" && "$@"
    fi
}

# ─── 1. Sous-dossiers ─────────────────────────────────────
echo ""
echo "1/8 Creation des dossiers..."
run mkdir -p "$PROJECT_DIR/voices/piper"
run mkdir -p "$PROJECT_DIR/venvs"
if [ "$TTS_ENGINE" = "coqui" ]; then
    run mkdir -p "$PROJECT_DIR/$COQUI_VENV"
fi

# ─── 2. Dépendances système ────────────────────────────────
echo ""
echo "2/8 Dépendances systeme..."
run apt-get update -qq
run apt-get install -y -qq espeak-ng ffmpeg python3-pip uv

# ─── 3. Piper ──────────────────────────────────────────────
echo ""
echo "3/8 Installation Piper..."
run pip install -q piper-tts

# ─── 4. Voix Piper ─────────────────────────────────────────
echo ""
echo "4/8 Voix Piper..."
VOICE_ONNX="$PROJECT_DIR/voices/piper/$PIPER_VOICE.onnx"
VOICE_JSON="$PROJECT_DIR/voices/piper/$PIPER_VOICE.onnx.json"
VOICE_PATH="fr/fr_FR/siwis/medium"

if [ ! -f "$VOICE_ONNX" ]; then
    echo "   Telechargement $PIPER_VOICE..."
    run wget -q "$PIPER_VOICE_URL/$VOICE_PATH/$PIPER_VOICE.onnx" -O "$VOICE_ONNX"
    run wget -q "$PIPER_VOICE_URL/$VOICE_PATH/$PIPER_VOICE.onnx.json" -O "$VOICE_JSON"
    echo "   OK"
else
    echo "   Voix deja presente"
fi

echo "   Écouter des échantillons: https://rhasspy.github.io/piper-samples/"

# ─── 5. Coqui (si configuré) ───────────────────────────────
echo ""
if [ "$TTS_ENGINE" = "coqui" ]; then
    echo "5/8 Installation Coqui TTS..."
    run uv venv --python 3.13 "$PROJECT_DIR/$COQUI_VENV"
    # shellcheck disable=SC1091
    source "$PROJECT_DIR/$COQUI_VENV/bin/activate"
    run uv pip install -q torch torchaudio torchcodec --torch-backend=cpu
    run uv pip install -q coqui-tts soundfile
    echo "   Modele VITS francais..."
    run python3 -c "from TTS.api import TTS; TTS('tts_models/fr/css10/vits')"
    echo "   Patch transformers..."
    AUTOREG="$PROJECT_DIR/$COQUI_VENV/lib/python3.13/site-packages/TTS/tts/layers/tortoise/autoregressive.py"
    if [ -f "$AUTOREG" ]; then
        run sed -i 's/from transformers.pytorch_utils import isin_mps_friendly as isin/import torch; isin = torch.isin/' "$AUTOREG"
    fi
    echo "   Coqui OK"
else
    echo "5/8 Coqui TTS ignore (TTS_ENGINE=$TTS_ENGINE)"
fi

# ─── 6. Service systemd ────────────────────────────────────
echo ""
echo "6/8 Service systemd..."
SERVICE_FILE="/etc/systemd/system/nabaztag-tts.service"
SERVICE_CONTENT="[Unit]
Description=Nabaztag TTS Proxy ($TTS_ENGINE)
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=$PROJECT_DIR/.env
WorkingDirectory=$PROJECT_DIR
ExecStart=$(which python3) $PROJECT_DIR/piper_tts_stream.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nabaztag-tts

[Install]
WantedBy=multi-user.target
"

if [ "$DRY_RUN" = true ]; then
    echo "   ❯ Service genere:"
    echo "$SERVICE_CONTENT" | sed 's/^/     /'
else
    echo "$SERVICE_CONTENT" > "$SERVICE_FILE"
    run systemctl daemon-reload
    run systemctl enable --now nabaztag-tts
    echo "   Service nabaztag-tts installe et demarre"
fi

# ─── 7. Résumé ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Installation terminee"
echo ""
echo "  Moteur TTS : $TTS_ENGINE"
echo "  Port       : $TTS_PORT"
echo "  Fichier    : $PROJECT_DIR/piper_tts_stream.py"
echo ""
echo "  Commandes:"
echo "    systemctl status nabaztag-tts"
echo "    journalctl -u nabaztag-tts -f"
echo "    curl http://localhost:$TTS_PORT/say?t=Bonjour -o test.wav"
echo "═══════════════════════════════════════════════════════"
