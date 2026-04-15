# Nabaztag Serverless - TTS Local avec Piper

## Préambule important

### IP utilisées (à adapter)

Les adresses IP utilisées dans ce projet sont des **exemples** et doivent être ajustées à votre configuration réseau:

- `192.168.0.42` - Adresse IP du serveur TTS (où tourne le proxy Python Piper)
- `192.168.0.58` - Adresse IP du Nabaztag (optionnel, pour info)

### Méthodologie générale (6 étapes)

1. **Cloner** le dépôt de base `andreax79/ServerlessNabaztag`
2. **Copier** les fichiers sources modifiés depuis le dossier `nab-piper/` vers le dossier cloné
3. **Compiler** le firmware (`make compiler` puis `make firmware`) → génère `vl/bc.jsp`
4. **Servir** le dossier `vl/` via un serveur web statique (accessible par le Nabaztag)
5. **Lancer** le serveur Python TTS (proxy Piper)
6. **Démarrer** le Nabaztag qui téléchargera le nouveau firmware depuis le serveur web

### Structure du projet

```
/opt/
├── ServerlessNabaztag/        # Dépôt cloné depuis github
│   ├── vl/                    # Fichiers Forth (dont bc.jsp après compilation)
│   ├── firmware/              # Code source MTL
│   ├── compiler/              # Compilateur
│   └── scripts/               # Scripts de compilation
│
└── nab-piper/                 # Nos modifications (ce dépôt)
    ├── vl/
    │   ├── hooks.forth        # Fonction say redirigée vers proxy TTS
    │   └── config.forth       # Authentification mise à jour
    ├── firmware/
    │   ├── audio/audiolib.mtl # Buffers optimisés
    │   ├── utils/
    │   │   ├── url.mtl        # Fonctions url_encode/url_decode
    │   │   └── config.mtl     # Langue française par défaut
    │   └── protos/
    │       └── ntp_protos.mtl # Serveur NTP à IP fixe
    ├── scripts/
    │   └── preproc.pl         # Timezone Europe/Paris
    ├── piper_tts_stream.py    # Proxy TTS Python
    ├── .env                   # Configuration environnement
    ├── piper-tts.service      # Service systemd
    ├── README.md              # Documentation
    └── CHANGELOG.md           # Historique des modifications
```

---

## Présentation

Ce projet remplace le système TTS Google Translate du Nabaztag par un moteur de synthèse vocale local utilisant **Piper** (TTS neuronal) avec traitement audio **FFmpeg**.

L'objectif est d'obtenir une voix française naturelle et de qualité sans dépendance externe, avec un démarrage rapide du Nabaztag.

---

## Architecture

```
┌─────────────────┐       ┌──────────────────┐       ┌─────────────────┐
│   Nabaztag v2   │       │   Serveur TTS    │       │     Piper      │
│  192.168.0.58   │──────▶│  192.168.0.42    │──────▶│  TTS neuronal   │
│                 │  HTTP │    :6790         │       │   (22kHz WAV)   │
│  say "texte"    │       │                  │       │                 │
└─────────────────┘       └────────┬─────────┘       └─────────────────┘
                                    │
                            ┌───────▼─────────┐
                            │     FFmpeg     │
                            │  16kHz + filtres│
                            │  + header WAV  │
                            └─────────────────┘
```

### Flux de données

1. **Déclenchement**: Le Nabaztag exécute `say "texte"` dans le Forth
2. **Requête**: Le firmware appelle `http://192.168.0.42:6790/say?t=texte_encodé`
3. **Génération**: Le proxy Python lance Piper pour générer l'audio
4. **Traitement**: FFmpeg rescanne à 16kHz et applique les filtres audio
5. **Streaming**: Le proxy renvoie le WAV au Nabaztag qui le joue

---

## Chainage audio: Comment le texte devient parole

Le système TTS utilise une chaîne de traitement en plusieurs étapes pour transformer le texte français du Nabaztag en audio jouable. Voici comment fonctionne ce chainage et à quoi servent les différentes options.

### Le processus de base

Cuando el Nabaztag ejecuta la orden "say" con un texto, este pasa por varias etapas antes de ser reproducido por el altavoz:

1. **Texte** → Le Nabaztag envoie le texte à dire au proxy Python
2. **Synthèse** → Piper convertit le texte en audio (voix française)
3. **Traitement** → FFmpeg adaptpe l'audio pour le Nabaztag (16kHz, filtres)
4. **Streaming** → Le proxy envoie le WAV final au Nabaztag

### Les trois composants

- **espeak-ng** (optionnel): Convertit le texte français en phonèmes IPA pour une meilleure prononciation
- **Piper**: Moteur de synthèse vocale neuronal qui génère l'audio à partir du texte ou des phonèmes
- **FFmpeg**: Traitement audio (resampling, filtres) pour adapter l'audio au petit haut-parleur du Nabaztag

### Options disponibles

Le proxy Python propose plusieurs flags pour configurer ce chainage:

- **`--phonemes`**: Active la conversion texte → phonèmes via espeak-ng avant l'envoi à Piper. Utile pour améliorer la prononciation de mots difficiles ou étrangers.

- **`--no-filters`**: Désactive les filtres FFmpeg (highpass, treble, volume) mais garde le resampling 16kHz. Utile pour tester ou comparer la qualité.

- **`--no-ffmpeg`**: Désactive complètement FFmpeg. Piper génère alors directement le WAV (22kHz) sans traitement. Utile pour le débogage.

**Configuration par défaut (recommandée):**
```bash
python piper_tts_stream.py
```
Cela active Piper + FFmpeg avec filtres, sans phonèmes.

**Pour activer les phonèmes:**
```bash
python piper_tts_stream.py --phonemes
```

---

## Fonctionnalités

### Proxy TTS (`piper_tts_stream.py`)

- **Synthèse vocale**: Piper avec voix française (fr_FR-siwis-medium)
- **Resampling**: Conversion 22kHz → 16kHz (compatible Nabaztag)
- **Filtres audio FFmpeg**:
  - `highpass=f=300` - Supprime les basses fréquences (petit haut-parleur)
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

## Fichiers du projet

### Firmware modifié

| Fichier | Modification |
|---------|-------------|
| `vl/hooks.forth` | Redirige `say` vers le proxy Piper |
| `firmware/audio/audiolib.mtl` | Buffers optimisés pour Nabaztag v2 |
| `firmware/utils/url.mtl` | Ajoute `url_encode`/`url_decode` |
| `firmware/utils/config.mtl` | Langue française par défaut |
| `firmware/protos/ntp_protos.mtl` | Serveur NTP à IP fixe |

### Nouveaux fichiers

| Fichier | Description |
|---------|-------------|
| `piper_tts_stream.py` | Proxy TTS principal |
| `.env` | Configuration environnement |
| `piper-tts.service` | Service systemd |

---

## Installation

### Prérequis serveur

```bash
# Debian/Ubuntu
apt install ffmpeg espeak-ng python3

# Installer Piper (voir https://github.com/OHF-Voice/piper1-gpl)
# Voix: fr_FR-siwis-medium, fr_FR-tom-medium
```

### Déploiement

Le déploiement se fait en suivant les 6 étapes de la méthodologie générale:

1. **Cloner le dépôt de base et ce depôt de sources modifiées**:

Les sources modifiées :

   ```bash
   git clone https://github.com/jsapede/nabaztag-piper.git nabaztag-piper
   ```

Le dépôt d'origine :

   ```bash
   git clone https://github.com/andreax79/ServerlessNabaztag.git ServerlessNabaztag
   cd ServerlessNabaztag
   ```

1. **Copier les fichiers sources modifiés depuis nab-piper/**:
   ```bash
   # Le dossier nab-piper/ doit être à côté de ServerlessNabaztag/
   cp ../nabaztag-piper/vl/hooks.forth vl/
   cp ../nabaztag-piper/vl/config.forth vl/
   cp ../nabaztag-piper/firmware/audio/audiolib.mtl firmware/audio/
   cp ../nabaztag-piper/firmware/utils/url.mtl firmware/utils/
   cp ../nabaztag-piper/firmware/utils/config.mtl firmware/utils/
   cp ../nabaztag-piper/firmware/protos/ntp_protos.mtl firmware/protos/
   cp ../nabaztag-piper/scripts/preproc.pl scripts/
   ```

2. **Compiler le firmware**:
   ```bash
   make compiler
   make firmware
   ```
   Le fichier `vl/bc.jsp` est généré.

3. **Servir le dossier vl/ via un serveur web statique**:
   Le Nabaztag téléchargera `vl/bc.jsp` au démarrage. Voir [andreax79/ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) pour les détails.

   **Option simple avec Python:**
   ```bash
   cd ServerlessNabaztag/
   python3 -m http.server 80
   ```

   **Option avec Docker (static-web-server):**
   ```yaml
   services:
     static-web-server:
       image: joseluisq/static-web-server:latest
       container_name: nabserver
       ports:
         - "80:80"
       volumes:
         - /opt/configs/nabserver:/var/public
       environment:
         SERVER_ROOT: "/var/public"
         SERVER_PORT: "80"
         SERVER_DIRECTORY_LISTING: "true"
       restart: unless-stopped
   ```
   Mettre le dossier `vl/` complet dans le volume servi par Docker.

4. **Copier et lancer le serveur Python TTS**:

ajustez le fichier `piper-tts.service` avant de le copier et le lancer :

   ```bash
   cp ../nab-piper/piper-tts.service /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable piper-tts
   systemctl start piper-tts
   ```

7. **Démarrer le Nabaztag**: Il téléchargera automatiquement le nouveau firmware depuis le serveur web.

---

## Configuration

### Modifier la voix

Editer `.env` avant de lancer le service:
```bash
PIPER_DEFAULT_VOICE=fr_FR-tom-medium  # Homme
# ou
PIPER_DEFAULT_VOICE=fr_FR-siwis-medium  # Femme
```

Rendez vous sur https://rhasspy.github.io/piper-samples/ pour choisir la voix qui vous intéresse. Certaines voix disposent de plusieurs "speakers", choisissez et ajustez dans le .env. Par défaut le speaker 0 est choisi.

### Modifier la vitesse

Dans `.env`:
```bash
PIPER_LENGTH_SCALE=1.0  # Normal
PIPER_LENGTH_SCALE=1.5  # Plus lent (défaut)
```

### Activer les phonèmes

Dans `.env`:
```bash
PIPER_USE_PHONEMES=true
```

### Autres paramètres configurables

Le fichier `.env` contient toutes les options configurables:

- **PIPER_BINARY**: Chemin vers l'exécutable Piper
- **PIPER_VOICES_FOLDER**: Dossier contenant les voix
- **PIPER_DEFAULT_VOICE**: Voix par défaut (fr_FR-siwis-medium ou fr_FR-tom-medium)
- **PIPER_LENGTH_SCALE**: Vitesse de la parole (1.0 = normal, 1.5 = plus lent)
- **FFMPEG_VOLUME**: Gain de volume (défaut: 1.5)
- **FFMPEG_HIGH_PASS**: Fréquence du filtre passe-haut (défaut: 300Hz)
- **FFMPEG_TREBLE**: Amplification des aigus en dB (défaut: 3)

**Note:** Après avoir modifié `.env`, redémarrer le service:
```bash
systemctl restart piper-tts
```

---

---

## Dépannage

### Le Nabaztag ne parle pas

```bash
# Vérifier que le service est actif
systemctl status piper-tts

# Voir les logs
journalctl -u piper-tts -f

# Tester manuellement
curl "http://192.168.0.42:6790/say?t=bonjour" -o test.wav
file test.wav  # Devrait être: RIFF WAVE audio
```

### Audio de mauvaise qualité

- Tester sans filtres: `--no-filters`
- Tester sans FFmpeg: `--no-ffmpeg`
- Vérifier le sample rate: `ffprobe -show_streams test.wav`

### Latence élevée

La valeur `WAV_BUFFER_STARTSIZE` peut être réduite (minimum recommandé: 32000). Toute modification dans les osurces necessitera de recompiler le firmware.

---

## Détails techniques

### Problème FFmpeg résolu

FFmpeg en mode streaming génère un header WAV invalide:
- Taille `ffff ffff` (inconnue)
- Chunk LIST supplémentaire

**Solution implémentée:** Utiliser `-f s16le` pour sortie PCM brute (sans header WAV), puis ajouter le header WAV manuellement en Python avec la bonne taille.

```python
def create_valid_wav_header(data_size, sample_rate=16000):
    """
    Crée un header WAV valide avec la taille correcte des données PCM.
    FFmpeg en streaming ne connaît pas la taille finale, d'où le problème.
    """
    header = bytearray(44)
    header[0:4] = b"RIFF"
    header[4:8] = struct.pack("<I", 36 + data_size)  # Taille RIFF = 36 + données
    header[8:12] = b"WAVE"
    # fmt chunk (24 bytes)
    header[12:16] = b"fmt "
    header[16:20] = struct.pack("<I", 16)  # Taille chunk fmt
    header[20:22] = struct.pack("<H", 1)   # Format: PCM
    header[22:24] = struct.pack("<H", 1)   # Canaux: mono
    header[24:28] = struct.pack("<I", sample_rate)  # Sample rate
    header[28:32] = struct.pack("<I", sample_rate * 2)  # Byte rate
    header[32:34] = struct.pack("<H", 2)   # Block align
    header[34:36] = struct.pack("<H", 16)  # Bits per sample
    # data chunk
    header[36:40] = b"data"
    header[40:44] = struct.pack("<I", data_size)  # Taille des données PCM
    return bytes(header)
```

### Commandes FFmpeg utilisées

```bash
# Entrée: WAV depuis Piper (22kHz)
ffmpeg -f wav -i - \
    # Filtres audio
    -af highpass=f=300,treble=g=3,volume=1.5 \
    # Resampling: 22kHz → 16kHz
    -ar 16000 \
    # Conversion mono
    -ac 1 \
    # Codec: 16-bit PCM
    -acodec pcm_s16le \
    # Sortie: PCM brut (pas de header WAV)
    -f s16le -
```

### Contraintes matérielles Nabaztag

- **Buffer initial**: 64KB (démarrage après ~0.5s)
- **Buffer maximum**: 512KB (stabilité WiFi)
- **Format audio**: 16kHz mono 16-bit PCM WAV
- **Client HTTP**: HTTP/1.0 (pas de chunked encoding)

---

## Licence

Ce projet est basé sur [andreax79/ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) et s'inspire également de:
- [Desperado88/nabaztag-home-assistant-2025](https://github.com/Desperado88/nabaztag-home-assistant-2025)

Piper est sous licence GPL - voir [OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl).
