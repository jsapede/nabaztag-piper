# Changelog - Nabaztag Serverless TTS

## 2026-04-18 - Auto-Control + Bug Fixes NTP

### Auto-control

4 drapeaux pour controler les comportements automatiques:

- **autoclock-enabled**: Annonces horaires (heure pile)
- **autohalftime-enabled**: Annonces demi-heures
- **autosurprise-enabled**: Sons surprise
- **autotaichi-enabled**: Mouvements taichi

### Bug Fix NTP critique

**Fichier**: `firmware/net/ntp.mtl`

**Probleme**: Le code original soustrayait l'uptime du timestamp NTP.

**Avant**:
```mtl
set time_high = (strgetword msg 40) - (now >> 16);
```

**Apres**:
```mtl
set time_high = strgetword msg 40;
```

### Bug Fix HTTP

**Fichier**: `firmware/srv/http_server.mtl`

- Double point-virgule manquant
- Parametre `list` -> `wlist`

### Endpoints /autocontrol et /autostatus

Supprimes du firmware. Utiliser `/forth` a la place.

---

## 2024-04-15 - Architecture TTS Complete

### Piper TTS

- Proxy Python avec Piper et FFmpeg
- Filtres audio: highpass, treble, volume
- Header WAV manuel
- Support phonemes espeak-ng

### Firmware modifies

| Fichier | Modification |
|---------|-------------|
| `vl/hooks.forth` | Redirection say vers proxy Piper |
| `vl/config.forth` | Authentification |
| `firmware/audio/audiolib.mtl` | Buffers: 64KB/512KB |
| `firmware/utils/url.mtl` | url_encode/url_decode |
| `firmware/utils/config.mtl` | Francais par defaut |
| `firmware/protos/ntp_protos.mtl` | NTP IP fixe |
| `scripts/preproc.pl` | Timezone Europe/Paris |

---

## Versions

| Version | Date | Description |
|---------|------|-------------|
| 2026-04-18 | Auto-control + Bug NTP + Bug HTTP |
| 2024-04-15 | Architecture TTS complete |
| 2024-04-14 | Version initiale Piper TTS |