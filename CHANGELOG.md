# Changelog - Nabaztag Serverless TTS

## 2026-04-29 - Fix compilation /autocontrol + Nettoyage

### Fix `/autocontrol` (compilation)

Le code MTL original utilisait `set autoclock-enabled@=clock` qui ne compile pas
(le compilateur MTL ne permet pas d'ecrire directement dans les variables Forth).

**Solution**: Utiliser `forth_interpreter_ex` pour executer le code Forth
`1 autoclock-enabled !` via l'interpreteur.

**Endpoint**: `GET /autocontrol?c=0/1&h=0/1&s=0/1&t=0/1`

| Param | Variable Forth |
|-------|----------------|
| c | autoclock-enabled |
| h | autohalftime-enabled |
| s | autosurprise-enabled |
| t | autotaichi-enabled |

### `/autostatus` supprime

Ne compile pas: le compilateur MTL ne connait pas les variables Forth.
Utiliser `/forth?c=autoclock-enabled%20@%20.` pour lire l'etat.

### Nettoyage Home Assistant

- Template Jinja2 mort dans Lovelace remplace par tableau statique
- `bootcode.bin` retire du suivi git (garder seulement `vl/bc.jsp`)
- `.env.example` complete avec `DEPLOY_TARGET`

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

Nouveaux endpoints REST pour controler les 4 drapeaux auto-control:

| Endpoint | Methode | Parametres | Description |
|----------|---------|------------|-------------|
| `/autocontrol` | GET | c=0/1, h=0/1, s=0/1, t=0/1 | Enable/disable les automatismes firmware |
| `/autostatus` | (supprime) | - | Utiliser /forth a la place |

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
| 2026-04-29 | Fix compilation /autocontrol + nettoyage repo |
| 2026-04-18 | Auto-control + Bug NTP + Bug HTTP |
| 2024-04-15 | Architecture TTS complete |
| 2024-04-14 | Version initiale Piper TTS |