# Changelog - Nabaztag Serverless TTS

## 2026-04-29 - Refactoring REST commands + Nettoyage final

### Refactoring REST commands (HA)

**20 commands unitaires → 2 commands generiques:**

| Avant | Apres |
|-------|-------|
| `nabaztag_say`, `nabaztag_left_ear`, `nabaztag_weather`... | `nabaztag_api(endpoint + query)` |
| `nabaztag_autocontrol_clock`, `_halftime`, `_surprise`, `_taichi` | `nabaztag_autocontrol(c/h/s/t)` |

**Fonctionnement**:
- `nabaztag_api`: endpoint = chemin HTTP, query = parametres optionnels
- `nabaztag_autocontrol`: 4 flags firmware en 1 appel HTTP
- Documentation complete des 25 endpoints dans `nabaztag_commands.yaml`

**Automations simplifiees**:
- `nabaztag_firmware_toggle`: 8 blocs `choose` → 1 seul appel `nabaztag_autocontrol`
- `nabaztag_reconnexion`: 7 actions REST → 3 actions REST
- Tous les Life scripts mis a jour

### REST sensors `/autostatus` + `/status`

- `sensor.nabaztag_status`: etat complet via `/status` (awake/asleep, config)
- `sensor.nabaztag_firmware_autostatus`: lecture des 4 flags firmware via `/autostatus`
- Dashboard Lovelace: section Diagnostic + Syncro HA vs Firmware

### Restauration endpoint `/autostatus` (firmware)

Initialement supprime car ne compilait pas. Re-ecrit via `forth_interpreter_ex`:

```mtl
_forth_http_autostatus_cb: recupere les 4 valeurs de la pile Forth
http_get_autostatus: execute "autoclock-enabled @ autohalftime-enabled @ ..."
```

**Endpoint**: `GET /autostatus` → `{"clock":1,"halftime":1,"surprise":1,"taichi":1}`

### Fix `/autocontrol` (compilation)

Le code MTL original `set autoclock-enabled@=clock` ne compile pas.
Remplace par `forth_interpreter_ex` qui execute `1 autoclock-enabled !`.

**Endpoint**: `GET /autocontrol?c=0/1&h=0/1&s=0/1&t=0/1`

| Param | Variable Forth |
|-------|----------------|
| c | autoclock-enabled |
| h | autohalftime-enabled |
| s | autosurprise-enabled |
| t | autotaichi-enabled |

### Nettoyage

- Template Jinja2 mort dans Lovelace remplace par tableau statique
- `bootcode.bin` retire du suivi git (garder seulement `vl/bc.jsp`)
- `.env.example` complete avec `DEPLOY_TARGET`
- Fonction morte `_http_forth_stack_json` supprimee du firmware

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
| 2026-04-29 | Refactoring REST commands + autostatus + sensors |
| 2026-04-18 | Auto-control + Bug NTP + Bug HTTP |
| 2024-04-15 | Architecture TTS complete |
| 2024-04-14 | Version initiale Piper TTS |