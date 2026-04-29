# Changelog - Nabaztag Serverless TTS

## 2026-04-29 - Corrections NTP, Taichi, LEDs, Installation

### Bug Fix NTP (calcul du temps)

**Fichier**: `firmware/utils/time.mtl`, `firmware/net/ntp.mtl`, `firmware/protos/time_protos.mtl`

**Probleme**: Le temps etait decale de plusieurs minutes car l'uptime au moment du sync NTP etait compte deux fois (dans le timestamp NTP et dans l'uptime ajoute au timezone offset).

**Correction**: Sauvegarde de l'uptime au moment du NTP (`_ntp_receive_time`), utilise `(time - _ntp_receive_time)` pour l'avancement de l'horloge au lieu de `time` (uptime complet). Intervalle NTP reduit a 1h.

### Bug Fix Taichi

**Fichier**: `vl/crontab.forth`

**Probleme**: Le mot Forth `taici-freq` n'existe pas (typo: `taichi-freq`). La fonction `calc-taichi` echouait silencieusement, le taichi ne se declenchait **jamais**.

### Bug Fix LEDs (Home Assistant)

**Fichier**: `homeassistant/nabaztag/nabaztag_automations.yaml`

**Probleme**: Le `choose` verifiait les etats en ordre. Togger pollution declenchait weather en premier (car weather ON). Correction: triggers separes avec `condition: trigger id`.

### Fonctionnalites

- **Flags auto-control dans `/status`**: `autoclock_enabled`, `autohalftime_enabled`, `autosurprise_enabled`, `autotaichi_enabled` lisibles directement (plus besoin de `/autostatus`)
- **`server-url` configurable**: Handler SET ajoute dans `forth_memory`, parametre `u=` dans `/setup`
- **`say`**: Utilise `TTS-SERVER$` constant au lieu d'IP hardcodee
- **Proxy charge `.env`**: Fonction `_load_env()` au demarrage, plus besoin de variables d'environnement
- **Install.sh**: Flag `--firmware`, skip si deja installe, stop/start services

### Corrections mineures

- `piper_tts_stream.py`: Retire `voice` param URL (engine selection uniquement via `.env`)
- `piper_tts_stream.py`: `COQUI_VENV` pointe vers `GLOBAL_DIR/.venv`
- `vl/locate.jsp`: Ajoute directive `# http`
- `install/.env.example`: Port par defaut 6790

---

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
| 2026-04-29 | Corrections NTP, Taichi, LEDs, Installation |
| 2026-04-18 | Auto-control + Bug NTP + Bug HTTP |
| 2024-04-15 | Architecture TTS complete |
| 2024-04-14 | Version initiale Piper TTS |