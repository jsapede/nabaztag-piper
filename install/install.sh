#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Nabaztag TTS — Installation, mise à jour et désinstallation
#
# Usage:
#   cd nabaztag-piper/install
#   ./install.sh                              # installation interactive
#   ./install.sh --dry-run                    # simulation
#   ./install.sh --firmware                   # recompilation firmware uniquement
#   ./install.sh --uninstall                  # désinstallation complète
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

# ─── Chemins ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Demande du dossier global (obligatoire) ─────────────────
while true; do
    printf " Dossier d'installation global : "
    read -r GLOBAL_DIR
    [ -n "$GLOBAL_DIR" ] && break
    echo "   Le dossier ne peut pas être vide"
done

# Vérifier que GLOBAL_DIR n'est pas le dossier du clone
if [ "$(realpath "$GLOBAL_DIR" 2>/dev/null)" = "$(realpath "$PROJECT_DIR" 2>/dev/null)" ]; then
    echo -e " ${RED}ERREUR${NC}: Le dossier global ne peut pas être le même que le dossier du dépôt"
    echo "   Dépôt: $PROJECT_DIR"
    echo "   Le dossier global doit être un répertoire dédié (ex: /opt/nabaztag-piper)"
    exit 1
fi

MANIFEST="$GLOBAL_DIR/install_manifest.json"

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
    printf "  ${CYAN}[?]${NC} $prompt [${default^^}/${default,,}] " >&2
    read -n 1 -r reply; echo >&2
    [ "${reply,,}" = "${default,,}" ] || [ "${reply,,}" = "y" ]
}

validate_ip() { [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; }

# ═══════════════════════════════════════════════════════════════
# MANIFEST
# ═══════════════════════════════════════════════════════════════

_manifest_init() {
    echo '{"manifest_version":1,"project":"nab-piper","source_dir":"","script_version":"0.1.0","created_at":"","updated_at":"","config":{},"components":{}}'
}

_manifest_load() {
    if [ -f "$MANIFEST" ]; then
        cat "$MANIFEST"
    else
        _manifest_init
    fi
}

_manifest_save() {
    echo "$MANIFEST_JSON" > "$MANIFEST"
}

_manifest_set() {
    local key="$1" installed="$2" version="$3" extra="$4"
    local ts now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    MANIFEST_JSON=$(echo "$MANIFEST_JSON" | python3 -c "
import sys, json
m = json.load(sys.stdin)
if 'components' not in m: m['components'] = {}
m['components']['$key'] = {'installed': $installed, 'detected_at': '$now'}
if '$version': m['components']['$key']['version'] = '$version'
$extra
m['updated_at'] = '$now'
json.dump(m, sys.stdout)
" 2>/dev/null || echo "$MANIFEST_JSON")
}

_manifest_remove() {
    local key="$1"
    MANIFEST_JSON=$(echo "$MANIFEST_JSON" | python3 -c "
import sys, json
m = json.load(sys.stdin)
if 'components' in m and '$key' in m['components']:
    del m['components']['$key']
m['updated_at'] = '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
json.dump(m, sys.stdout)
" 2>/dev/null || echo "$MANIFEST_JSON")
}

_manifest_clear() { rm -f "$MANIFEST"; }

_manifest_detect() {
    local now rev
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Piper
    if which piper >/dev/null 2>&1; then
        local pv=$(piper --version 2>/dev/null | head -1 | grep -oP '[\d\.]+' | head -1)
        _manifest_set piper true "${pv:-unknown}" "\"binary\": \"$(which piper)\","
    else
        _manifest_set piper false "" ""
    fi

    # FFmpeg
    if which ffmpeg >/dev/null 2>&1; then
        local fv=$(ffmpeg -version 2>/dev/null | head -1 | grep -oP '[\d\.]+' | head -1)
        _manifest_set ffmpeg true "${fv:-unknown}" "\"binary\": \"$(which ffmpeg)\","
    else
        _manifest_set ffmpeg false "" ""
    fi

    # espeak-ng
    if which espeak-ng >/dev/null 2>&1; then
        local ev=$(espeak-ng --version 2>/dev/null | head -1 | grep -oP '[\d\.]+' | head -1)
        _manifest_set espeak_ng true "${ev:-unknown}" "\"binary\": \"$(which espeak-ng)\","
    else
        _manifest_set espeak_ng false "" ""
    fi

    # Voix Piper
    local voice_path="$GLOBAL_DIR/voices/piper/$PIPER_VOICE_PATH"
    if [ -f "$voice_path.onnx" ]; then
        _manifest_set piper_voice true "${voice_path##*/}" "\"path\": \"$voice_path.onnx\","
    else
        _manifest_set piper_voice false "" ""
    fi

    # Firmware compile
    if [ -f "$GLOBAL_DIR/firmware/vl/bc.jsp" ]; then
        rev=$(grep -oP 'Rev: \K\d+' "$GLOBAL_DIR/firmware/vl/bc.jsp" 2>/dev/null || echo "unknown")
        _manifest_set firmware true "$rev" "\"path\": \"$GLOBAL_DIR/firmware/vl/bc.jsp\","
    else
        _manifest_set firmware false "" ""
    fi

    # Services
    local stt=$(systemctl is-active nabaztag-tts 2>/dev/null || echo "inactive")
    _manifest_set service_tts true "" "\"name\": \"nabaztag-tts\", \"state\": \"$stt\","
    local sws=$(systemctl is-active nabaztag-webserver 2>/dev/null || echo "inactive")
    _manifest_set service_webserver true "" "\"name\": \"nabaztag-webserver\", \"state\": \"$sws\","

    _manifest_save
}

_manifest_show_status() {
    local m=$(_manifest_load)
    echo ""
    echo " État des composants installés :"
    for key in piper ffmpeg espeak_ng piper_voice firmware service_tts service_webserver; do
        local state=$(echo "$m" | python3 -c "
import sys, json
m = json.load(sys.stdin)
c = m.get('components', {}).get('$key', {})
if c.get('installed'):
    v = c.get('version','')
    print('${GREEN}✓${NC} $key' + (f' (v{v})' if v else ''))
else:
    print('${RED}✗${NC} $key')
" 2>/dev/null || echo "   $key: ?")
        echo -e "   $state"
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
        echo "   [G]arder l'existant (ne rien changer)"
        echo "   [R]ecréer avec l'assistant interactif"
        echo "   [A]bandonner"
        printf "   Choix [G] : "
        read -n 1 -r reply; echo
        case "${reply,,}" in
            r) ;;
            a) echo "Installation abandonnée"; exit 1 ;;
            *) echo "   Utilisation de l'existant"; source "$GLOBAL_DIR/.env"; return 0 ;;
        esac
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

    if [ "$FIRMWARE_ONLY" = false ]; then
        while true; do
            printf " IP du serveur TTS : "; read -r ip
            tts_ip="${ip:-}"
            [ -n "$tts_ip" ] && validate_ip "$tts_ip" && break
            [ -n "$tts_ip" ] || echo " IP obligatoire"
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
    else
        tts_ip="$TTS_SERVER_IP"
        tts_port="${TTS_PORT:-6790}"
        web_port="${WEB_SERVER_PORT:-80}"
        engine="${TTS_ENGINE:-piper}"
    fi

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
        _manifest_clear
        run rm -rf "$GLOBAL_DIR"
        echo "  ${GREEN}$GLOBAL_DIR supprimé${NC}"
    fi
    echo "  Désinstallation terminée"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# INSTALLATION PRINCIPALE
# ═══════════════════════════════════════════════════════════════

# ─── Phase 1 : Environnement ────────────────────────────────
_interactive_env
MANIFEST_JSON=$(_manifest_load)
MANIFEST_JSON=$(echo "$MANIFEST_JSON" | python3 -c "
import sys, json
m = json.load(sys.stdin)
m['source_dir'] = '$PROJECT_DIR'
if 'config' not in m: m['config'] = {}
m['config']['tts_server_ip'] = '$TTS_SERVER_IP'
m['config']['tts_port'] = '${TTS_PORT:-6790}'
m['config']['web_server_port'] = '${WEB_SERVER_PORT:-80}'
m['config']['tts_engine'] = '${TTS_ENGINE:-piper}'
m['config']['piper_voice_path'] = '${PIPER_VOICE_PATH:-fr/fr_FR/siwis/medium}'
m['config']['espeak_voice'] = '${ESPEAK_VOICE:-fr}'
if not m.get('created_at'): m['created_at'] = '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
json.dump(m, sys.stdout)
")
_manifest_save

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
    local old_revision=""
    # Sauvegarder l'ancienne révision si fichier déjà modifié
    [ -f "$SOURCE_DIR/firmware/utils/url.mtl" ] && old_revision=$(grep -oP 'XXX_REVISION_XXX' "$SOURCE_DIR/firmware/utils/url.mtl" || echo "")

    # Copier les sources dans un répertoire temporaire pour ne pas polluer le repo
    run cp -r "$SOURCE_DIR/compiler" "$build_dir/" 2>/dev/null || true
    run cp -r "$SOURCE_DIR/firmware" "$build_dir/" 2>/dev/null || true
    run cp "$SOURCE_DIR/Makefile" "$build_dir/" 2>/dev/null || true
    mkdir -p "$build_dir/vl"
    run cp "$SOURCE_DIR/vl/config.forth" "$build_dir/vl/" 2>/dev/null || true

    # Injecter l'IP du TTS dans la copie (pas dans l'original)
    run sed -i "s|XXX\.XXX\.XXX\.XXX:[0-9]*|$TTS_SERVER_IP:$TTS_PORT|;s|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:[0-9]*|$TTS_SERVER_IP:$TTS_PORT|" \
        "$build_dir/vl/config.forth" 2>/dev/null || true
    # Injecter le timestamp dans les copies (pas dans l'original)
    REVISION_STAMP=$(date +%Y%m%d%H%M)
    run sed -i "s|XXX_REVISION_XXX|$REVISION_STAMP|" "$build_dir/firmware/utils/url.mtl" 2>/dev/null || true
    run sed -i "s|XXX_REVISION_XXX|$REVISION_STAMP|" "$build_dir/firmware/main.mtl" 2>/dev/null || true
    echo "   Revision firmware: $REVISION_STAMP"

    # Compiler depuis le répertoire temporaire
    run make -C "$build_dir" compiler 2>&1 || echo "   Compilateur déjà présent ou absent (pre-compilé utilisé)"
    run make -C "$build_dir" firmware 2>&1 || true

    # Copier le résultat vers GLOBAL_DIR
    run mkdir -p "$GLOBAL_DIR/firmware/vl"
    run cp -r "$build_dir/vl/." "$GLOBAL_DIR/firmware/vl/" 2>/dev/null || true
    if [ -f "$GLOBAL_DIR/firmware/vl/bc.jsp" ]; then
        echo "   Firmware -> $GLOBAL_DIR/firmware/vl/bc.jsp"
        _manifest_set firmware true "$REVISION_STAMP" "\"path\": \"$GLOBAL_DIR/firmware/vl/bc.jsp\","
        _manifest_save
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

# ─── Mode firmware uniquement ────────────────────────────
if [ "$FIRMWARE_ONLY" = true ]; then
    SOURCE_DIR="$PROJECT_DIR"
    _compile_firmware
    exit 0
fi

# ─── Phase 3 : Détection composants ──────────────────────
_manifest_detect

# ─── Phase 4 : Menu interactif (sauf dry-run) ────────────
REINSTALL_PIPER=false
REINSTALL_DEPS=false
REINSTALL_VOICE=false
REINSTALL_SERVICES=false

if [ "$DRY_RUN" = false ]; then
    _manifest_show_status
    echo ""
    echo " Composants à (ré)installer (o = oui, Entrée = non) :"
    echo "  (le firmware et le redémarrage des services sont toujours effectués)"

    m=$(_manifest_load)
    for key in piper ffmpeg espeak_ng piper_voice service_tts service_webserver; do
        installed=$(echo "$m" | python3 -c "
import sys, json
m = json.load(sys.stdin)
c = m.get('components', {}).get('$key', {})
print('true' if c.get('installed') else 'false')
" 2>/dev/null || echo "false")
        label=""
        case "$key" in
            piper) label="Piper binaire";;
            ffmpeg) label="FFmpeg";;
            espeak_ng) label="espeak-ng";;
            piper_voice) label="Modèle de voix";;
            service_tts) label="Service TTS";;
            service_webserver) label="Serveur web";;
        esac
        if [ "$installed" = "true" ]; then
            if prompt_yn "$label déjà installé — Réinstaller ?" n; then
                case "$key" in
                    piper) REINSTALL_PIPER=true;;
                    ffmpeg|espeak_ng) REINSTALL_DEPS=true;;
                    piper_voice) REINSTALL_VOICE=true;;
                    service_tts|service_webserver) REINSTALL_SERVICES=true;;
                esac
            fi
        else
            echo -e "  ${CYAN}→${NC} $label sera installé (composant manquant)"
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
            _manifest_set "$pkg" true "" "\"binary\":\"$(which $pkg 2>/dev/null || true)\","
        fi
    done
    _manifest_save
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
        run wget -q "$PIPER_VOICE_URL/$PIPER_VOICE_PATH/$VOICE_NAME.onnx" -O "$voice_path.onnx"
        run wget -q "$PIPER_VOICE_URL/$PIPER_VOICE_PATH/$VOICE_NAME.onnx.json" -O "$voice_path.onnx.json"
        echo "     OK"
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
_manifest_set piper true "$(piper --version 2>/dev/null | head -1 | grep -oP '[\d\.]+' | head -1 || echo unknown)" "\"binary\":\"$(which piper 2>/dev/null || true)\","

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

# ─── Finalisation manifeste ───────────────────────────────
_manifest_detect

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
echo "  Manifest  : $MANIFEST"
echo ""
echo "  systemctl status nabaztag-tts"
echo "  journalctl -u nabaztag-tts -f"
echo "  journalctl -u nabaztag-webserver -f"
echo ""
echo "  Désinstaller : ./install.sh --uninstall"
echo "═══════════════════════════════════════════════════════"
