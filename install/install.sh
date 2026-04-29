#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Nabaztag TTS — Installation, mise à jour et désinstallation
#
# Usage:
#   cd nabaztag-piper/install
#   cp .env.example /opt/nabaztag-piper/.env  &&  vi /opt/nabaztag-piper/.env
#   ./install.sh                              # installation
#   ./install.sh --dry-run                    # simulation
#   ./install.sh --firmware                   # recompilation firmware uniquement
#   ./install.sh --uninstall                  # désinstallation complète
#
# Le script détecte si .env a changé et réapplique les modifications.
# ═══════════════════════════════════════════════════════════════

set -e

# ─── Modes ───────────────────────────────────────────────────
DRY_RUN=false
UNINSTALL=false
FIRMWARE_ONLY=false
for arg in "$@"; do
    [ "$arg" = "--dry-run" ] && DRY_RUN=true
    [ "$arg" = "--uninstall" ] && UNINSTALL=true
    [ "$arg" = "--firmware" ] && FIRMWARE_ONLY=true
done

# ─── Chemins automatiques ────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

run() {
    if [ "$DRY_RUN" = true ]; then echo -e "  ${YELLOW}❯${NC} $*"
    else echo -e "  ${GREEN}❯${NC} $*" && "$@"
    fi
}

# ─── Chargement .env ─────────────────────────────────────────
# .env doit etre dans GLOBAL_DIR (pas dans le repo source)
GLOBAL_DIR="${GLOBAL_DIR:-/opt/nabaztag-piper}"
if [ -f "$GLOBAL_DIR/.env" ]; then
    source "$GLOBAL_DIR/.env"
elif [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
elif [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo -e "${RED}ERREUR${NC}: .env introuvable"
    echo "  cp install/.env.example $GLOBAL_DIR/.env"
    echo "  vi $GLOBAL_DIR/.env  # editer la configuration"
    exit 1
fi

SOURCE_DIR="$PROJECT_DIR"

# Nom de voix depuis le chemin
VOICE_NAME=$(echo "$PIPER_VOICE_PATH" | awk -F/ '{print $2"-"$3"-"$4}')

# Chemins codés en dur
COQUI_VENV="$GLOBAL_DIR/.venv"
PIPER_VOICES_DIR="$GLOBAL_DIR/voices/piper"
PIPER_VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main"
SWS_VERSION="v2.42.0"
SWS_BIN="/usr/local/bin/static-web-server"

# ─── Désinstallation ─────────────────────────────────────────
if [ "$UNINSTALL" = true ]; then
    echo "═══════════════════════════════════════════════════════"
    echo " Désinstallation Nabaztag TTS"
    echo "═══════════════════════════════════════════════════════"
    run systemctl stop nabaztag-tts 2>/dev/null || true
    run systemctl disable nabaztag-tts 2>/dev/null || true
    run rm -f /etc/systemd/system/nabaztag-tts.service
    run systemctl stop nabaztag-webserver 2>/dev/null || true
    run systemctl disable nabaztag-webserver 2>/dev/null || true
    run rm -f /etc/systemd/system/nabaztag-webserver.service
    run systemctl daemon-reload
    echo ""
    echo -e "  ${YELLOW}Supprimer $GLOBAL_DIR ? (y/N)${NC}"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        run rm -rf "$GLOBAL_DIR"
        echo "  ${GREEN}$GLOBAL_DIR supprime${NC}"
    fi
    echo "  Désinstallation terminee"
    exit 0
fi

# ─── Vérification des changements ────────────────────────────
CHANGED=""
[ -f "$GLOBAL_DIR/.env" ] && CHANGED=$(diff -q "$PROJECT_DIR/.env" "$GLOBAL_DIR/.env" 2>/dev/null && echo "" || echo "env")

# ─── Installation ────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════"
echo " Nabaztag TTS — Installation"
echo " Source  : $SOURCE_DIR"
echo " Global  : $GLOBAL_DIR"
echo " Moteur  : ${TTS_ENGINE:-piper}"
echo " VoIP    : $VOICE_NAME"

# ─── Détection IP TTS ────────────────────────────────────
TTS_SERVER_IP="${TTS_SERVER_IP:-XXX.XXX.XXX.XXX}"
if [ "$TTS_SERVER_IP" = "XXX.XXX.XXX.XXX" ]; then
    DETECTED_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e " ${YELLOW}⚠️  TTS_SERVER_IP non configure${NC}"
    echo "   IP detectee : $DETECTED_IP"
    echo "   Le Nabaztag utilisera cette IP pour le TTS"
    echo "   (port ${TTS_PORT:-6790})"
    echo ""
    printf "   Confirmer l'IP [%s] : " "$DETECTED_IP"
    read -r input
    TTS_SERVER_IP="${input:-$DETECTED_IP}"
fi
[ -n "$CHANGED" ] && echo -e " ${YELLOW}Configuration modifiee, reinstallation${NC}"
echo "═══════════════════════════════════════════════════════"

# ─── Compilation firmware (utilisee par --firmware et etape 7) ─

_compile_firmware() {
    [ -n "$CHANGED" ] && (run make -C "$SOURCE_DIR" clean 2>/dev/null) || true
    run sed -i "s|XXX\.XXX\.XXX\.XXX:[0-9]*|$TTS_SERVER_IP:$TTS_PORT|;s|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:[0-9]*|$TTS_SERVER_IP:$TTS_PORT|" \
        "$SOURCE_DIR/vl/config.forth" 2>/dev/null || true
    run make -C "$SOURCE_DIR" compiler 2>&1 || echo "   Compilateur deja present ou absent (pre-compiled utilise)"
    run make -C "$SOURCE_DIR" firmware 2>&1 || true
    run cp -r "$SOURCE_DIR/vl/." "$GLOBAL_DIR/firmware/vl/" 2>/dev/null || true
    if [ -f "$GLOBAL_DIR/firmware/vl/bc.jsp" ]; then
        echo "   Firmware -> $GLOBAL_DIR/firmware/vl/bc.jsp"
    else
        echo "   AVERTISSEMENT: firmware non compile - utiliser un binaire pre-compile"
    fi
}

# ─── Mode firmware uniquement ────────────────────────────
if [ "$FIRMWARE_ONLY" = true ]; then
    _compile_firmware
    exit 0
fi

# ─── 1. Dossier global ───────────────────────────────────────
echo ""
echo "1/10 Dossier global..."
run mkdir -p "$GLOBAL_DIR/voices/piper"
run mkdir -p "$GLOBAL_DIR/firmware/vl"

# ─── 2. Copie des fichiers ───────────────────────────────────
echo ""
echo "2/10 Copie des fichiers..."
run cp "$SCRIPT_DIR/piper_tts_stream.py" "$GLOBAL_DIR/"
run cp "$SCRIPT_DIR/coqui_cli.py" "$GLOBAL_DIR/"

# ─── 3. Dépendances système ──────────────────────────────────
echo ""
echo "3/10 Dépendances systeme..."
# Check uv
which uv >/dev/null 2>&1 && echo "   uv present" || (curl -LsSf https://astral.sh/uv/install.sh | sh)
# Refresh PATH after uv install
export PATH="$HOME/.local/bin:$PATH"
which uv >/dev/null 2>&1 || (echo "ERREUR: uv non installe"; exit 1)

DEPS="espeak-ng ffmpeg python3-pip build-essential make"
for pkg in $DEPS; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "   $pkg present"
    else
        run apt-get install -y -qq "$pkg"
    fi
done

# ─── 4. Piper ────────────────────────────────────────────────
if [ "$TTS_ENGINE" != "coqui" ]; then
echo ""
echo "4/10 Installation Piper..."
if which piper >/dev/null 2>&1; then
    echo "   Piper deja installe"
else
    run uv pip install --system -q piper-tts
fi

# ─── 5. Voix Piper ───────────────────────────────────────────
echo ""
echo "5/10 Voix Piper..."
VOICE_ONNX="$PIPER_VOICES_DIR/$VOICE_NAME.onnx"
VOICE_JSON="$PIPER_VOICES_DIR/$VOICE_NAME.onnx.json"

if [ ! -f "$VOICE_ONNX" ] || [ -n "$CHANGED" ]; then
    echo "   Telechargement $VOICE_NAME..."
    run wget -q "$PIPER_VOICE_URL/$PIPER_VOICE_PATH/$VOICE_NAME.onnx" -O "$VOICE_ONNX"
    run wget -q "$PIPER_VOICE_URL/$PIPER_VOICE_PATH/$VOICE_NAME.onnx.json" -O "$VOICE_JSON"
    echo "   OK"
else
    echo "   Voix deja presente"
fi
echo "   Samples: https://rhasspy.github.io/piper-samples/"
else
echo "4/10 Piper ignore (TTS_ENGINE=$TTS_ENGINE)"
echo "5/10 Voix Piper ignore (TTS_ENGINE=$TTS_ENGINE)"
fi

# ─── 6. Coqui ────────────────────────────────────────────────
echo ""
if [ "$TTS_ENGINE" = "coqui" ]; then
    echo "6/10 Installation Coqui TTS..."
    if [ ! -d "$COQUI_VENV" ] || [ -n "$CHANGED" ]; then
        run uv venv --python 3.13 "$COQUI_VENV"
    fi
    source "$COQUI_VENV/bin/activate"
    if "$COQUI_VENV/bin/python3" -c "import TTS" 2>/dev/null && [ -z "$CHANGED" ]; then
        echo "   Coqui deja installe"
    else
        run uv pip install -q torch torchaudio torchcodec --torch-backend=cpu
        run uv pip install -q coqui-tts soundfile
        echo "   Modele VITS francais..."
        run python3 -c "from TTS.api import TTS; TTS('tts_models/fr/css10/vits')"
        AUTOREG=$(find "$COQUI_VENV/lib" -path "*/TTS/tts/layers/tortoise/autoregressive.py" 2>/dev/null | head -1)
        if [ -n "$AUTOREG" ] && [ -f "$AUTOREG" ]; then
            grep -q "isin_mps_friendly" "$AUTOREG" && run sed -i 's/from transformers.pytorch_utils import isin_mps_friendly as isin/import torch; isin = torch.isin/' "$AUTOREG" || true
        fi
    fi
else
    echo "6/10 Coqui ignore (TTS_ENGINE=$TTS_ENGINE)"
fi

# ─── 7. Compilation firmware ─────────────────────────────────
echo ""
echo "7/10 Compilation du firmware (IP TTS: $TTS_SERVER_IP:$TTS_PORT)..."
_compile_firmware

# ─── 8. Serveur web static-web-server ─────────────────────────
echo ""
echo "8/10 Installation serveur web..."
if [ ! -f "$SWS_BIN" ] || [ -n "$CHANGED" ]; then
    SWS_URL="https://github.com/static-web-server/static-web-server/releases/download/$SWS_VERSION/static-web-server-$SWS_VERSION-x86_64-unknown-linux-gnu.tar.gz"
    run wget -q "$SWS_URL" -O /tmp/sws.tar.gz
    SWS_DIR=$(tar tzf /tmp/sws.tar.gz | head -1 | cut -d/ -f1)
    run tar xzf /tmp/sws.tar.gz -C /usr/local/bin/ --strip-components=1 "$SWS_DIR/static-web-server"
    run chmod +x "$SWS_BIN"
    run rm -f /tmp/sws.tar.gz
fi

# ─── 9. Service nabaztag-tts ─────────────────────────────────
echo ""
echo "9/10 Service nabaztag-tts..."
SERVICE_CONTENT="[Unit]
Description=Nabaztag TTS Proxy ($TTS_ENGINE)
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=$GLOBAL_DIR/.env
WorkingDirectory=$GLOBAL_DIR
ExecStart=$(which python3) $GLOBAL_DIR/piper_tts_stream.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nabaztag-tts

[Install]
WantedBy=multi-user.target
"
echo "$SERVICE_CONTENT" > /tmp/nabaztag-tts.service
if [ "$DRY_RUN" = true ]; then
    echo "   Service genere:"
    sed 's/^/     /' /tmp/nabaztag-tts.service
else
    run cp /tmp/nabaztag-tts.service /etc/systemd/system/nabaztag-tts.service
    run systemctl daemon-reload
    run systemctl enable --now nabaztag-tts
fi
rm -f /tmp/nabaztag-tts.service

# ─── 10. Service nabaztag-webserver ──────────────────────────
echo ""
if [ -f "$GLOBAL_DIR/firmware/vl/bc.jsp" ]; then
    echo "10/10 Service nabaztag-webserver..."
    WEB_PORT="${WEB_SERVER_PORT:-80}"
    WEB_CONTENT="[Unit]
Description=Nabaztag Firmware Web Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SWS_BIN --port ${WEB_SERVER_PORT:-80} --root $GLOBAL_DIR/firmware --log-level info --directory-listing true
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nabaztag-webserver

[Install]
WantedBy=multi-user.target
"
    echo "$WEB_CONTENT" > /tmp/nabaztag-webserver.service
    if [ "$DRY_RUN" = true ]; then
        echo "   Service genere:"
        sed 's/^/     /' /tmp/nabaztag-webserver.service
    else
        run cp /tmp/nabaztag-webserver.service /etc/systemd/system/nabaztag-webserver.service
        run systemctl daemon-reload
        run systemctl enable --now nabaztag-webserver
    fi
    rm -f /tmp/nabaztag-webserver.service
else
    echo "10/10 Service web : firmware non compile, service DESACTIVE"
fi

# ─── Résumé ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo -e " ${GREEN}Installation terminee${NC}"
echo ""
echo "  Proxy TTS : $GLOBAL_DIR/piper_tts_stream.py"
echo "  Moteur    : ${TTS_ENGINE:-piper}"
echo "  Port TTS  : ${TTS_PORT:-6790}"
echo "  Web serveur: http://localhost:${WEB_SERVER_PORT:-80}/vl/"
echo ""
echo "  systemctl status nabaztag-tts"
echo "  journalctl -u nabaztag-tts -f"
echo "  journalctl -u nabaztag-webserver -f"
echo ""
echo "  Desinstaller : ./install.sh --uninstall"
echo "═══════════════════════════════════════════════════════"
