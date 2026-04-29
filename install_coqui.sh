#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────
# Installer Coqui TTS pour Nabaztag
# Usage: ./install_coqui.sh
#   Options:
#     --xtts   Telecharger aussi XTTS v2 (multi-voix, ~3.5GB)
#     --help   Afficher l'aide
# ──────────────────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="/opt/coqui-tts"
DOWNLOAD_XTTS=false

echo "╔═══════════════════════════════════════════════════╗"
echo "║     Installation Coqui TTS pour Nabaztag         ║"
echo "╚═══════════════════════════════════════════════════╝"

# Options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --xtts) DOWNLOAD_XTTS=true; shift ;;
    --help) echo "Usage: $0 [--xtts]"; exit 0 ;;
    *) echo "Option inconnue: $1"; exit 1 ;;
  esac
done

echo ""
echo "1/6 Creation du venv..."
uv venv --python 3.13 "$VENV_DIR" 2>/dev/null || true
source "$VENV_DIR/bin/activate"

echo "2/6 Installation PyTorch CPU + torchaudio..."
uv pip install torch torchaudio torchcodec --torch-backend=cpu -q

echo "3/6 Installation Coqui TTS..."
uv pip install coqui-tts[server] soundfile -q

echo "4/6 Patch compatibilite transformers..."
AUTOREGRESSIVE="$VENV_DIR/lib/python3.13/site-packages/TTS/tts/layers/tortoise/autoregressive.py"
if [ -f "$AUTOREGRESSIVE" ]; then
  sed -i 's/from transformers.pytorch_utils import isin_mps_friendly as isin/import torch; isin = torch.isin/' "$AUTOREGRESSIVE"
  echo "   Patch applique: isin_mps_friendly -> torch.isin"
fi

echo "5/6 Telechargement des modeles..."

# VITS français (toujours)
echo "   - VITS francais (tts_models/fr/css10/vits)..."
python3 -c "from TTS.api import TTS; TTS('tts_models/fr/css10/vits')" 2>/dev/null
echo "     OK"

# XTTS v2 (optionnel)
if [ "$DOWNLOAD_XTTS" = true ]; then
  echo "   - XTTS v2 multilingue (tts_models/multilingual/multi-dataset/xtts_v2)..."
  echo "     Telechargement ~3.5GB, patience..."
  python3 -c "
from TTS.api import TTS
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2')
speakers = tts.speakers or []
print(f'     OK — {len(speakers)} voix disponibles')
if speakers:
    print(f'     Exemples: {speakers[:10]}')
" 2>/dev/null
fi

echo "6/6 Configuration des variables d'environnement..."
ENV_FILE="$SCRIPT_DIR/.env"
if ! grep -q "COQUI_MODEL" "$ENV_FILE" 2>/dev/null; then
  cat >> "$ENV_FILE" << 'EOF'

# ─── Coqui TTS (utilise avec le flag --coqui sur le proxy) ─────
COQUI_MODEL=vits              # vits | xtts
COQUI_SPEAKER=Frederic        # voix XTTS (ignore si vits)
COQUI_LANGUAGE=fr
EOF
  echo "   Ajoute a .env"
fi

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║  Installation terminee !                          ║"
echo "║                                                   ║"
echo "║  Utilisation:                                     ║"
echo "║    source $VENV_DIR/bin/activate           ║"
echo "║    echo 'Bonjour' | python3 coqui_cli.py > out.wav ║"
echo "║                                                   ║"
echo "║  Proxy TTS:                                       ║"
echo "║    python3 piper_tts_stream.py --port 6790        ║"
echo "║    python3 piper_tts_stream.py --port 6790 --coqui║"
echo "╚═══════════════════════════════════════════════════╝"
