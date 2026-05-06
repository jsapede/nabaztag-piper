#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Nabaztag TTS — Installation, mise à jour et désinstallation
#
# Usage:
#   cd nabaztag-piper/install
#   ./install.sh                              # installation interactive
#   ./install.sh --dry-run                    # simulation
#   ./install.sh --uninstall                  # désinstallation complète
# ═══════════════════════════════════════════════════════════════

set -e

# ─── IP locale (par défaut pour TTS + serveur web) ──────────
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
LOCAL_IP="${LOCAL_IP:-127.0.0.1}"

# ─── Modes ───────────────────────────────────────────────────
DRY_RUN=false
UNINSTALL=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true;;
        --uninstall) UNINSTALL=true;;
        *) echo -e "${RED}Erreur${NC}: option inconnue '$arg'"
           echo "  Usage: ./install.sh [--dry-run] [--uninstall]"
           exit 1;;
    esac
done

# ─── Chemins ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Demande du dossier global ──────────────────────────────
printf " Dossier d'installation global [/opt/nab-tts] : "
read -r input
GLOBAL_DIR="${input:-/opt/nab-tts}"

# Vérifier que GLOBAL_DIR n'est pas le dossier du clone
if [ "$(realpath "$GLOBAL_DIR" 2>/dev/null)" = "$(realpath "$PROJECT_DIR" 2>/dev/null)" ]; then
    echo -e " ${RED}ERREUR${NC}: Le dossier global ne peut pas être le même que le dossier du dépôt"
    echo "   Dépôt: $PROJECT_DIR"
    echo "   Le dossier global doit être un répertoire dédié (ex: /opt/nabaztag-piper)"
    exit 1
fi

# ─── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

run() {
    if [ "$DRY_RUN" = true ]; then echo -e "  ${YELLOW}❯${NC} $*"
    else echo -e "  ${GREEN}❯${NC} $*" && "$@"
    fi
}

prompt_yn() {
    local prompt="$1" default="${2:-n}" reply
    if [ "$DRY_RUN" = true ]; then echo "  ${CYAN}[?]${NC} $prompt (simulation)"; return 0; fi
    while true; do
        if [ "$default" = "y" ]; then
            printf "  ${CYAN}[?]${NC} $prompt [${CYAN}Y${NC}/n] " >&2
        else
            printf "  ${CYAN}[?]${NC} $prompt [y/${CYAN}N${NC}] " >&2
        fi
        read -n 1 -r reply; echo >&2
        case "${reply,,}" in
            y) return 0 ;;
            n) return 1 ;;
            "") [ "$default" = "y" ] && return 0 || return 1 ;;
        esac
    done
}

validate_ip() { [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; }

# ═══════════════════════════════════════════════════════════════
# DÉTECTION COMPOSANTS
# ═══════════════════════════════════════════════════════════════

_check_component() {
    case "$1" in
        piper)        which piper >/dev/null 2>&1 ;;
        ffmpeg)       which ffmpeg >/dev/null 2>&1 ;;
        espeak_ng)    which espeak-ng >/dev/null 2>&1 ;;
        piper_voice)  [ -f "$PIPER_VOICES_DIR/$VOICE_NAME.onnx" ] ;;
        firmware)     [ -f "$GLOBAL_DIR/firmware/vl/bc.jsp" ] ;;
        service_tts)  systemctl is-active nabaztag-tts >/dev/null 2>&1 ;;
        service_webserver) systemctl is-active nabaztag-webserver >/dev/null 2>&1 ;;
        uv)           which uv >/dev/null 2>&1 ;;
        *)            return 1 ;;
    esac
}

_component_label() {
    case "$1" in piper) echo "Piper binaire";; ffmpeg) echo "FFmpeg";; espeak_ng) echo "espeak-ng";; piper_voice) echo "Modèle de voix";; firmware) echo "Firmware";; service_tts) echo "Service TTS";; service_webserver) echo "Serveur web";; uv) echo "uv";; esac
}

_show_status() {
    echo ""
    echo " État des composants installés :"
    for c in piper ffmpeg espeak_ng piper_voice firmware service_tts service_webserver; do
        if _check_component "$c"; then echo -e "   ${GREEN}✓${NC} $(_component_label "$c")"
        else echo -e "   ${RED}✗${NC} $(_component_label "$c")"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION INTERACTIVE
# ═══════════════════════════════════════════════════════════════

_interactive_env() {
    local reply
    if [ -f "$GLOBAL_DIR/.env" ]; then
        echo ""
        echo -e " ${YELLOW}⚠️  .env déjà présent dans $GLOBAL_DIR${NC}"
        while true; do
            echo "   [G]arder l'existant (ne rien changer)"
            echo "   [R]ecréer avec l'assistant interactif"
            echo "   [A]bandonner"
            printf "   Choix [G] : "
            read -n 1 -r reply; echo
            case "${reply,,}" in
                r) break ;;
                a) echo "Installation abandonnée"; exit 1 ;;
                g) echo "   Utilisation de l'existant"; source "$GLOBAL_DIR/.env"; return 0 ;;
                *) echo -e "   ${YELLOW}Réponse invalide (G, R ou A)${NC}" ;;
            esac
        done
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo " Configuration interactive"
    echo " (Entrée = valeur par défaut entre crochets)"
    echo "═══════════════════════════════════════════════════════"

    local ip lapin_ip tts_port web_port engine
    while true; do
        printf " IP du Nabaztag [192.168.0.58] : "; read -r ip
        lapin_ip="${ip:-192.168.0.58}"
        validate_ip "$lapin_ip" && break
        echo -e " ${RED}Format IP invalide${NC}"
    done

    while true; do
        printf " IP du serveur TTS [$LOCAL_IP] : "; read -r ip
        tts_ip="${ip:-$LOCAL_IP}"
        validate_ip "$tts_ip" && break
        echo -e " ${RED}Format IP invalide${NC}"
    done
    while true; do
        printf " Port du serveur TTS [6790] : "; read -r port
        tts_port="${port:-6790}"
        [[ "$tts_port" =~ ^[0-9]+$ ]] && [ "$tts_port" -ge 1 ] && [ "$tts_port" -le 65535 ] && break
        echo " Port invalide (1-65535)"
    done
    while true; do
        printf " Port du serveur web [80] : "; read -r port
        web_port="${port:-80}"
        [[ "$web_port" =~ ^[0-9]+$ ]] && [ "$web_port" -ge 1 ] && [ "$web_port" -le 65535 ] && break
        echo " Port invalide (1-65535)"
    done
    while true; do
        printf " Moteur TTS (piper/coqui) [piper] : "; read -r engine
        engine="${engine:-piper}"
        [[ "$engine" == "piper" || "$engine" == "coqui" ]] && break
        echo " Choix invalide (piper ou coqui)"
    done

    mkdir -p "$GLOBAL_DIR"
    cat > "$GLOBAL_DIR/.env" << EOF
# ═══════════════════════════════════════════════════════════
# Nabaztag Piper — Configuration (généré par install.sh)
# ═══════════════════════════════════════════════════════════
GLOBAL_DIR=$GLOBAL_DIR
NABAZTAG_IP=$lapin_ip
TTS_SERVER_IP=$tts_ip
TTS_PORT=$tts_port
TTS_ENGINE=$engine
WEB_SERVER_PORT=$web_port
PIPER_VOICE_PATH=fr/fr_FR/siwis/medium
PIPER_SPEAKER=0
PIPER_LENGTH_SCALE=1.5
PIPER_NOISE_SCALE=0.667
PIPER_NOISE_W_SCALE=0.333
PIPER_VOLUME=1
PIPER_SENTENCE_SILENCE=0.2
PIPER_USE_PHONEMES=true
ESPEAK_VOICE=fr
COQUI_MODEL=vits
EOF

    echo -e " ${GREEN}.env créé dans $GLOBAL_DIR/.env${NC}"

    # Copier et injecter le package HA
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$GLOBAL_DIR/homeassistant/nabaztag"
        cp -r "$PROJECT_DIR/homeassistant/nabaztag/"*.yaml "$GLOBAL_DIR/homeassistant/nabaztag/" 2>/dev/null || true
        if [ -f "$GLOBAL_DIR/homeassistant/nabaztag/nabaztag_inputs.yaml" ]; then
            sed -i "s/192\.168\.0\.58/$lapin_ip/g" "$GLOBAL_DIR/homeassistant/nabaztag/nabaztag_inputs.yaml"
            echo -e " ${GREEN}Package HA : IP lapin injectée dans nabaztag_inputs.yaml${NC}"
        fi
        echo "   Package HA : $GLOBAL_DIR/homeassistant/nabaztag/"
        # Copier le script telnet
        mkdir -p "$GLOBAL_DIR/homeassistant/python_scripts"
        cp "$PROJECT_DIR/homeassistant/python_scripts/nab-telnet.py" "$GLOBAL_DIR/homeassistant/python_scripts/" 2>/dev/null || true
        echo "   Script telnet : $GLOBAL_DIR/homeassistant/python_scripts/nab-telnet.py"
    fi

    source "$GLOBAL_DIR/.env"
}

# ═══════════════════════════════════════════════════════════════
# DÉSINSTALLATION
# ═══════════════════════════════════════════════════════════════

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
        echo -e "  ${GREEN}$GLOBAL_DIR supprimé${NC}"
    fi
    echo "  Désinstallation terminée"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# INSTALLATION PRINCIPALE
# ═══════════════════════════════════════════════════════════════

# ─── Phase 1 : Environnement ────────────────────────────────
_interactive_env

VOICE_NAME=$(echo "$PIPER_VOICE_PATH" | awk -F/ '{print $2"-"$3"-"$4}')
COQUI_VENV="$GLOBAL_DIR/.venv"
PIPER_VOICES_DIR="$GLOBAL_DIR/voices/piper"
PIPER_VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main"
SWS_VERSION="v2.42.0"
SWS_BIN="/usr/local/bin/static-web-server"
TTS_SERVER_IP="${TTS_SERVER_IP:-XXX.XXX.XXX.XXX}"
TTS_PORT="${TTS_PORT:-6790}"

# ─── Phase 2 : Compilation firmware (TOUJOURS) ──────────────
_compile_firmware() {
    local build_dir=$(mktemp -d)

    echo ""
    echo " ╔══════════════════════════════════════════════════════"
    echo " ║  Build système (Makefile du projet)"
    echo " ║"
    echo " ║  La révision du firmware est automatiquement injectée"
    echo " ║  par le Makefile : date +%Y%m%d%H%M"
    echo " ║"
    echo " ║  AVANT de compiler, vérifiez que la date et l'heure"
    echo " ║  de votre système sont correctes !"
    echo " ║  Date actuelle : $(date '+%Y-%m-%d %H:%M')"
    echo " ║"
    echo " ╚══════════════════════════════════════════════════════"

    # Copier les sources dans un répertoire temporaire pour ne pas polluer le repo
    run cp -r "$SOURCE_DIR/compiler" "$build_dir/" 2>/dev/null || true
    run cp -r "$SOURCE_DIR/firmware" "$build_dir/" 2>/dev/null || true
    run cp "$SOURCE_DIR/Makefile" "$build_dir/" 2>/dev/null || true
    run cp -r "$SOURCE_DIR/scripts" "$build_dir/" 2>/dev/null || true
    run cp -r "$SOURCE_DIR/vl" "$build_dir/" 2>/dev/null || true

    # Injecter l'IP du TTS dans la copie (pas dans l'original)
    run sed -i "s|XXX\.XXX\.XXX\.XXX:[0-9]*|$TTS_SERVER_IP:$TTS_PORT|;s|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:[0-9]*|$TTS_SERVER_IP:$TTS_PORT|" \
        "$build_dir/vl/config.forth" 2>/dev/null || true
    echo "   IP TTS injectée dans config.forth"

    # Compiler depuis le répertoire temporaire
    run make -C "$build_dir" compiler 2>&1 || echo "   Compilateur déjà présent ou absent (pre-compilé utilisé)"
    run make -C "$build_dir" firmware 2>&1 || true

    # Copier le résultat vers GLOBAL_DIR
    run mkdir -p "$GLOBAL_DIR/firmware/vl"
    run cp -r "$build_dir/vl/." "$GLOBAL_DIR/firmware/vl/" 2>/dev/null || true
    if [ -f "$GLOBAL_DIR/firmware/vl/bc.jsp" ]; then
        local built_revision=$(strings "$GLOBAL_DIR/firmware/vl/bc.jsp" 2>/dev/null | grep "Rev:" | head -1 | sed 's/.*Rev: \([0-9]*\)\$$/\1/')
        echo "   Firmware -> $GLOBAL_DIR/firmware/vl/bc.jsp (rev: ${built_revision:-?})"
    else
        echo "   AVERTISSEMENT: firmware non compilé - utiliser un binaire pre-compilé"
    fi

    rm -rf "$build_dir"
}

echo "═══════════════════════════════════════════════════════"
echo " Nabaztag TTS — Installation"
echo " Source  : $PROJECT_DIR"
echo " Global  : $GLOBAL_DIR"
echo " Moteur  : ${TTS_ENGINE:-piper}"
echo " VoIP    : $VOICE_NAME"
echo "═══════════════════════════════════════════════════════"

# ─── Phase 3 : Détection composants + menu ─────────────────
_show_status

REINSTALL_PIPER=false
REINSTALL_DEPS=false
REINSTALL_VOICE=false
REINSTALL_SERVICES=false

if [ "$DRY_RUN" = false ]; then
    echo ""
    echo " Composants à (ré)installer (o = oui, Entrée = non) :"
    echo "  (le firmware et le redémarrage des services sont toujours effectués)"

    for pair in piper:piper ffmpeg:ffmpeg espeak_ng:espeak_ng piper_voice:piper_voice service_tts:service_tts service_webserver:service_webserver; do
        key="${pair%%:*}"
        label="$(_component_label "$key")"
        if _check_component "$key"; then
            if prompt_yn "$label déjà présent — Forcer la réinstallation ?" n; then
                case "$key" in
                    piper) REINSTALL_PIPER=true;;
                    ffmpeg|espeak_ng) REINSTALL_DEPS=true;;
                    piper_voice) REINSTALL_VOICE=true;;
                    service_tts|service_webserver) REINSTALL_SERVICES=true;;
                esac
            fi
        else
            echo "  → $label sera installé (composant manquant)"
            case "$key" in
                piper) REINSTALL_PIPER=true;;
                ffmpeg|espeak_ng) REINSTALL_DEPS=true;;
                piper_voice) REINSTALL_VOICE=true;;
                service_tts|service_webserver) REINSTALL_SERVICES=true;;
            esac
        fi
    done
fi

SOURCE_DIR="$PROJECT_DIR"

# ─── Phase 5 : Exécution ─────────────────────────────────
echo ""
echo "━━━ Installation en cours ━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Dossier global
echo "  → Dossier global..."
run mkdir -p "$GLOBAL_DIR/voices/piper"
run mkdir -p "$GLOBAL_DIR/firmware/vl"

# 2. Copie des fichiers
echo "  → Copie des fichiers..."
run cp "$SCRIPT_DIR/piper_tts_stream.py" "$GLOBAL_DIR/"
run cp "$SCRIPT_DIR/coqui_cli.py" "$GLOBAL_DIR/"

# 3. Dépendances système
if [ "$REINSTALL_DEPS" = true ]; then
    echo "  → Dépendances système..."
    which uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    DEPS="espeak-ng ffmpeg python3-pip build-essential make"
    for pkg in $DEPS; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            echo "     $pkg présent"
        else
            run apt-get install -y -qq "$pkg"
            _manifest_set "$pkg" true "" "{\"binary\":\"$(which $pkg 2>/dev/null || true)\"}"
        fi
    done
else
    echo "  → Dépendances système : déjà installées"
fi

# 4. Piper
run systemctl stop nabaztag-tts 2>/dev/null || true
if [ "$TTS_ENGINE" != "coqui" ]; then
    echo "  → Piper..."
    if [ "$REINSTALL_PIPER" = true ] || ! which piper >/dev/null 2>&1; then
        run uv pip install --system -q piper-tts
    else
        echo "     Piper déjà installé"
    fi
    # 5. Voix
    echo "  → Voix Piper..."
    voice_path="$PIPER_VOICES_DIR/$VOICE_NAME"
    if [ "$REINSTALL_VOICE" = true ] || [ ! -f "$voice_path.onnx" ]; then
        echo "     Téléchargement $VOICE_NAME..."
        run wget -q --timeout=30 "$PIPER_VOICE_URL/$PIPER_VOICE_PATH/$VOICE_NAME.onnx" -O "$voice_path.onnx" || echo "     ⚠️ Échec du téléchargement (ressayez avec ./install.sh)"
        run wget -q --timeout=30 "$PIPER_VOICE_URL/$PIPER_VOICE_PATH/$VOICE_NAME.onnx.json" -O "$voice_path.onnx.json" || echo "     ⚠️ Échec du téléchargement .json"
        if [ -f "$voice_path.onnx" ]; then
            echo "     OK"
        else
            echo -e "     ${RED}ÉCHEC${NC} — vérifiez votre connexion Internet"
        fi
    else
        echo "     Voix déjà présente (conservée)"
    fi
    echo "     Samples: https://rhasspy.github.io/piper-samples/"
else
    echo "  → Piper : ignoré (moteur Coqui)"
    echo "  → Voix : ignorée (moteur Coqui)"
fi

# 6. Coqui (si sélectionné)
if [ "$TTS_ENGINE" = "coqui" ]; then
    echo "  → Coqui TTS..."
    if [ ! -d "$COQUI_VENV" ]; then
        run uv venv --python 3.13 "$COQUI_VENV"
    fi
    source "$COQUI_VENV/bin/activate"
    if "$COQUI_VENV/bin/python3" -c "import TTS" 2>/dev/null; then
        echo "     Coqui déjà installé"
    else
        run uv pip install -q torch torchaudio --torch-backend=cpu
        run uv pip install -q coqui-tts soundfile
        echo "     Modèle VITS français..."
        run python3 -c "from TTS.api import TTS; TTS('tts_models/fr/css10/vits')"
    fi
else
    echo "  → Coqui : ignoré"
fi

# 7. Compilation firmware (toujours)
echo "  → Compilation du firmware (IP TTS: $TTS_SERVER_IP:$TTS_PORT)..."
_compile_firmware

# 8. Serveur web statique
echo "  → Serveur web statique..."
if [ ! -f "$SWS_BIN" ]; then
    sws_url="https://github.com/static-web-server/static-web-server/releases/download/$SWS_VERSION/static-web-server-$SWS_VERSION-x86_64-unknown-linux-gnu.tar.gz"
    run wget -q "$sws_url" -O /tmp/sws.tar.gz
    sws_dir=$(tar tzf /tmp/sws.tar.gz | head -1 | cut -d/ -f1)
    run tar xzf /tmp/sws.tar.gz -C /usr/local/bin/ --strip-components=1 "$sws_dir/static-web-server"
    run chmod +x "$SWS_BIN"
    run rm -f /tmp/sws.tar.gz
else
    echo "     static-web-server déjà présent"
fi

# 9. Service TTS
echo "  → Service nabaztag-tts..."
cat > /tmp/nabaztag-tts.service << UNIT
[Unit]
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
UNIT
run cp /tmp/nabaztag-tts.service /etc/systemd/system/nabaztag-tts.service
run rm -f /tmp/nabaztag-tts.service

# 10. Service web
echo "  → Service nabaztag-webserver..."
if [ -f "$GLOBAL_DIR/firmware/vl/bc.jsp" ]; then
    cat > /tmp/nabaztag-webserver.service << UNIT
[Unit]
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
UNIT
    run cp /tmp/nabaztag-webserver.service /etc/systemd/system/nabaztag-webserver.service
    run rm -f /tmp/nabaztag-webserver.service
else
    echo "     Service web : firmware non compilé, service DESACTIVÉ"
fi

# Redémarrage des services (toujours)
echo "  → Redémarrage des services..."
run systemctl daemon-reload
run systemctl enable --now nabaztag-tts 2>/dev/null || true
run systemctl enable --now nabaztag-webserver 2>/dev/null || true

# Rechargement des animations (après redémarrage des services)
if [ "$DRY_RUN" = false ] && [ -n "${NABAZTAG_IP:-}" ]; then
    echo "  → Rechargement des animations sur le lapin (attendez...)"
    if command -v python3 >/dev/null 2>&1 && [ -f "$PROJECT_DIR/homeassistant/python_scripts/nab-telnet.py" ]; then
        python3 "$PROJECT_DIR/homeassistant/python_scripts/nab-telnet.py" "$NABAZTAG_IP" "load-info-animations"
        sleep 1
        python3 "$PROJECT_DIR/homeassistant/python_scripts/nab-telnet.py" "$NABAZTAG_IP" "0 1 info-set"
    else
        printf "\n load-info-animations cr 0 1 info-set cr quit\n" | timeout 10 nc "$NABAZTAG_IP" 23 2>/dev/null || true
    fi
    echo "   ✓ Animations rechargées sur le lapin"
fi

# ─── Script de vérification ────────────────────────────────
echo "  → Script de vérification..."
if [ "$DRY_RUN" = false ]; then
    cat > "$GLOBAL_DIR/nabaztag-check.sh" << 'SCRIPT'
#!/bin/bash
echo "═══ Services Nabaztag ═══"

check() {
    if systemctl is-active "$1" >/dev/null 2>&1; then echo "  $1 : ${GREEN}✓ actif${NC}"
    else echo "  $1 : ${RED}✗ inactif${NC}"
    fi
}

check nabaztag-tts
check nabaztag-webserver

echo ""
echo "═══ Derniers logs ═══"
echo "--- TTS ---"
journalctl -u nabaztag-tts -n 5 --no-pager 2>/dev/null || echo "  (pas de logs)"
echo ""
echo "--- Web ---"
journalctl -u nabaztag-webserver -n 5 --no-pager 2>/dev/null || echo "  (pas de logs)"

echo ""
echo "═══ Commandes ═══"
echo "  Logs TTS  : journalctl -u nabaztag-tts -f"
echo "  Logs Web  : journalctl -u nabaztag-webserver -f"
echo "  Redémarrer: systemctl restart nabaztag-tts nabaztag-webserver"
SCRIPT
    chmod +x "$GLOBAL_DIR/nabaztag-check.sh"
    # Proposer l'alias bash
    if ! grep -q "nabaztag-check" ~/.bashrc 2>/dev/null; then
        echo "alias nabaztag='$GLOBAL_DIR/nabaztag-check.sh'" >> ~/.bashrc
        echo "   Alias bash 'nabaztag' ajouté (source ~/.bashrc ou rouvrez votre terminal)"
    fi
fi

# ─── Résumé ──────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo -e " ${GREEN}Installation terminée${NC}"
echo ""
echo "  Proxy TTS : $GLOBAL_DIR/piper_tts_stream.py"
echo "  Moteur    : ${TTS_ENGINE:-piper}"
echo "  Port TTS  : ${TTS_PORT:-6790}"
echo "  Web serveur: http://localhost:${WEB_SERVER_PORT:-80}/vl/"
echo "  Package HA : $GLOBAL_DIR/homeassistant/nabaztag/"
echo "              → copier vers /config/nabaztag/ dans HA"
echo "              → IP lapin déjà injectée dans input_text.nabaztag_ip_address"
echo "  Script telnet : $GLOBAL_DIR/homeassistant/python_scripts/nab-telnet.py"
echo "                → copier vers /config/python_scripts/ dans HA"
echo "  Check     : $GLOBAL_DIR/nabaztag-check.sh"
echo "  Alias     : nabaztag (dans le terminal)"
echo ""
echo "  systemctl status nabaztag-tts"
echo "  journalctl -u nabaztag-tts -f"
echo "  journalctl -u nabaztag-webserver -f"
echo ""
echo "  Désinstaller : ./install.sh --uninstall"
echo "═══════════════════════════════════════════════════════"
