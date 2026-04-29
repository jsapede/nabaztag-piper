#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────
# Installer le service systemd Piper TTS
# Usage: ./install.sh [install_dir]
#        (defaut: dossier courant)
# ──────────────────────────────────────────────────────────────────────────

set -e

INSTALL_DIR="${1:-$(pwd)}"
SERVICE_NAME="piper-tts"

echo "📦 Installation du service $SERVICE_NAME"
echo "   Repertoire d'installation: $INSTALL_DIR"

# Vérifier que les fichiers existent
if [ ! -f "$INSTALL_DIR/piper_tts_stream.py" ]; then
    echo "❌ $INSTALL_DIR/piper_tts_stream.py introuvable"
    echo "   Lancer depuis le dossier du projet ou specifier le chemin:"
    echo "   ./install.sh /chemin/vers/nabaztag-piper"
    exit 1
fi

if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "⚠️  $INSTALL_DIR/.env introuvable — copie depuis .env.example"
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
fi

# Générer le service avec le bon chemin
sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
    "$INSTALL_DIR/piper-tts.service" > "/etc/systemd/system/$SERVICE_NAME.service"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "✅ Service $SERVICE_NAME installe et demarre"
echo "   Logs: journalctl -u $SERVICE_NAME -f"
echo "   Test: curl 'http://$(grep ^TTS_SERVER "$INSTALL_DIR/.env" | cut -d= -f2):$(grep ^TTS_PORT "$INSTALL_DIR/.env" | cut -d= -f2)/say?t=bonjour' -o /tmp/test.wav"
