# Changelog - Nabaztag Serverless TTS

Historique des modifications apportées au firmware et à l'architecture TTS du Nabaztag.

---

## 2024-04-15 - Architecture TTS Complete

### Nouveaux fichiers créés

#### `piper_tts_stream.py` (Proxy TTS principal)
Proxy Python complet pour le texte-vers-speech avec Piper et FFmpeg.

**Fonctionnalités:**
- Conversion texte → phonèmes via espeak-ng (optionnel, flag `--phonemes`)
- Resampling audio vers 16kHz (compatible Nabaztag)
- Filtres FFmpeg: highpass (300Hz), treble (+3dB), volume (1.5x)
- Création manuelle du header WAV (résout les problèmes de FFmpeg en streaming)
- Support CLI: `--no-ffmpeg`, `--no-filters`, `--phonemes`
- Variables d'environnement configurables

#### `.env` (Configuration)
Fichier de configuration avec toutes les variables d'environnement:
- Configuration Piper (voix, vitesse, bruit)
- Configuration espeak-ng pour les phonèmes
- Configuration FFmpeg (filtres, sample rate)

#### `piper-tts.service` (Systemd)
Service systemd pour démarrage automatique du proxy TTS.

---

### Modifications du firmware

#### `vl/hooks.forth` - Fonction say
**Avant:**
```forth
nil "http://translate.google.com/translate_tts?ie=UTF-8&total=1&idx=0&textlen=32&client=tw-ob&tl=" :: language @ :: "&q=" :: r> :: str-join
```

**Après:**
```forth
nil "http://192.168.0.42:6790/say?t=" :: r> :: str-join
```

**But:** Remplacer Google Translate TTS par le proxy Piper local pour une synthèse vocale de qualité sans dépendance externe.

---

#### `vl/config.forth` - Authentification
**Modification:** Mise à jour du hash MD5 du mot de passe.

**But:** Authentification fonctionnelle pour l'accès Telnet/administration.

---

#### `firmware/audio/audiolib.mtl` - Buffers audio

**Avant:**
```mtl
const WAV_BUFFER_STARTSIZE=80000;;
const WAV_BUFFER_MAXSIZE=400000;;
```

**Après:**
```mtl
const WAV_BUFFER_STARTSIZE=64000;;
const WAV_BUFFER_MAXSIZE=512000;;
```

**But:**
- `WAV_BUFFER_STARTSIZE`: Réduction de 80KB à 64KB pour un démarrage plus rapide (~0.5s au lieu de ~2.5s)
- `WAV_BUFFER_MAXSIZE`: Augmentation de 400KB à 512KB pour une meilleure gestion des instabilités WiFi

---

#### `firmware/utils/url.mtl` - Encodage URL
**Ajout:** Fonctions `url_encode` et `url_decode` (RFC 3986)

```mtl
fun url_encode text= ...    // Encode les caractères spéciaux pour URL
fun url_decode url_encoded= // Décode les %XX en caractères
```

**But:** Nécessaire pour encoder correctement le texte avant de l'envoyer au proxy TTS. Le Nabaztag doit encoder les espaces, accents, etc.

---

#### `firmware/utils/config.mtl` - Langue par défaut

**Avant:**
```mtl
fun config_get_lang =
    let _config_get CONF_LANGUAGE 2 -> val in
    if val == nil then "" else val;;
```

**Après:**
```mtl
fun config_get_lang =
    let _config_get CONF_LANGUAGE 2 -> val in
    if val == nil || val == "" then "fr" else val;;
```

**But:** Le français est utilisé par défaut si aucune langue n'est configurée. Cela assure que la voix française de Piper est utilisée.

---

#### `firmware/protos/ntp_protos.mtl` - Serveur NTP

**Avant:**
```mtl
var ntp_server = "pool.ntp.org";
```

**Après:**
```mtl
var ntp_server = "216.239.35.12";
```

**But:** Utiliser une IP fixe (Google time server) au lieu d'un nom de domaine. Plus fiable sur les réseaux avec DNS filtré ou problématique.

---

#### `scripts/preproc.pl` - Timezone

**Avant:**
```perl
my $datetime = gmtime->datetime;
```

**Après:**
```perl
$ENV{TZ} = 'Europe/Paris';
my $datetime = localtime->datetime;
```

**But:** L'horodatage du firmware utilise maintenant l'heure locale (Europe/Paris) au lieu de UTC. Cela facilite le débogage et correspond à l'usage réel du Nabaztag.

---

## 2024-04-14 - Version initiale Piper TTS

### Changements
- **Remplacement de Google Translate**: Redirection de la fonction `say` vers un proxy local
- **Nouveau Proxy**: Script `piper_tts_proxy.py` pour interfacer le lapin avec l'API Piper
- **Configuration**: Mise à jour des identifiants Telnet par défaut
- **NTP**: Passage aux serveurs de temps Google pour plus de fiabilité
- **Timezone**: Correction de la gestion de l'heure locale (Europe/Paris)
- **Langue**: Forçage du français par défaut si non défini

---

## Notes techniques

### Problème FFmpeg résolu
FFmpeg en mode streaming génère un header WAV invalide:
- Taille `ffff ffff` (inconnue)
- Chunk LIST supplémentaire

**Cause:** FFmpeg ne connaît pas la taille totale des données quand il écrit en streaming (pipe). Il écrit donc `ffff ffff` comme taille inconnue, et ajoute parfois un chunk LIST parasite.

**Solution:** Utiliser `-f s16le` pour sortie PCM brute (sans header WAV), puis ajouter le header WAV manuellement en Python avec `create_valid_wav_header()` qui connaît la taille finale des données.

### Chainage espeak-ng → Piper → FFmpeg

Le système utilise un chainage complet pour une qualité optimale:

```
Texte français
     │
     ▼ (optionnel --phonemes)
espeak-ng ──→ Phonèmes IPA (ex: "bɔ̃ʒuʁ")
     │
     ▼
Piper ──→ Audio WAV (22kHz)
     │
     ▼
FFmpeg ──→ Resampling 16kHz + filtres + header WAV
     │
     ▼
Nabaztag (16kHz mono 16-bit PCM)
```

#### Pourquoi espeak-ng?
- Piper fonctionne mieux avec des phonèmes IPA qu'avec du texte brut
- espeak-ng convertit précisément le français vers IPA
- Syntaxe: `[[phonemes IPA]]` pour que Piper les interprétent directement

#### Pourquoi FFmpeg?
- **Resampling:** Piper sort en 22kHz, le Nabaztag attend 16kHz
- **Filtres:** Le petit haut-parleur du Nabaztag ne peut pas reproduire les basses fréquences, donc on les supprime avec highpass
- **Volume:** Le volume interne est faible, on l'amplifie de 1.5x

### Chainages possibles
```bash
# Défaut: Piper + FFmpeg + filtres (sans phonèmes)
python piper_tts_stream.py

# Avec phonèmes (espeak-ng)
python piper_tts_stream.py --phonemes

# Piper seul (pas de transcoding)
python piper_tts_stream.py --no-ffmpeg

# FFmpeg resampling seulement (pas de filtres)
python piper_tts_stream.py --no-filters
```

### Dépendances serveur Python
- `piper` (synthèse vocale)
- `ffmpeg` (traitement audio)
- `espeak-ng` (conversion texte → phonèmes IPA, optionnel)
- Python 3.x

---

## Historique des versions

| Version | Date | Description |
|---------|------|-------------|
| 2024-04-15 | 2024-04-15 | Architecture TTS complète avec phonèmes, filtres FFmpeg, service systemd |
| 2024-04-14 | 2024-04-14 | Version initiale Piper TTS |
