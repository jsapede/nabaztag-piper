# Nabaztag Serverless - TTS Local avec Piper

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      HOME ASSISTANT                           │
│                                                               │
│  rest_command.nabaztag_api ───▶ HTTP GET                     │
│  rest_command.nabaztag_autocontrol ───▶ HTTP GET             │
│  sensor.nabaztag_status ◀─── HTTP GET (via REST sensor)      │
│  sensor.nabaztag_firmware_autostatus ◀─── HTTP GET           │
│                                                               │
│  Automations: reconnexion, toggle LEDs, trafic, firmware      │
│  Scripts: restore LEDs, oreilles, parole, setup               │
│  Nabaztag Life: 10 scripts + 5 automations                   │
└──────────────────────┬────────────────────────────────────────┘
                       │ HTTP
┌──────────────────────▼────────────────────────────────────────┐
│                      NABAZTAG FIRMWARE                         │
│                                                               │
│  /autocontrol ──▶ forth_interpreter ──▶ set flags              │
│  /autostatus  ──▶ forth_interpreter ──▶ read flags             │
│  /forth       ──▶ forth_interpreter ──▶ arbitrary Forth code   │
│  /say         ──▶ say() ──▶ HTTP ──▶ +─────────────────────+ │
│  /weather     ──▶ info_service_update   │   Piper TTS       │ │
│  /traffic     ──▶ info_service_update   │   192.168.0.42    │ │
│  ...           ──▶ divers endpoints     │   :6790           │ │
│                                         │   (FFmpeg + Piper)│ │
│  Automatismes firmware (autonomes):     └───────────────────┘ │
│    autoclock-enabled (on-time hook)                            │
│    autohalftime-enabled (on-halftime hook)                     │
│    autosurprise-enabled (crontab)                              │
│    autotaichi-enabled (crontab)                                │
└──────────────────────────────────────────────────────────────┘
```

---

## Endpoints REST du firmware

| Endpoint | Methode | Parametres | Description |
|----------|---------|------------|-------------|
| `/autocontrol` | GET | c=0/1, h=0/1, s=0/1, t=0/1 | Controler les 4 automatismes firmware |
| `/autostatus` | GET | - | JSON `{clock,halftime,surprise,taichi}` |
| `/status` | GET | - | JSON complet (sleep, config, leds, ears...) |
| `/say` | GET | t=texte | Parler (TTS via Piper) |
| `/left` | GET | p=0..16, d=0 | Oreille gauche |
| `/right` | GET | p=0..16, d=0 | Oreille droite |
| `/nose` | GET | v=0..4 | LED Nez |
| `/weather` | GET | v=0..5 | LED Meteo |
| `/traffic` | GET | v=0..6 | LED Trafic |
| `/pollution` | GET | v=0..10 | LED Pollution |
| `/clear` | GET | - | Reset toutes les LEDs |
| `/setup` | GET | j=&k=&l=&c=&d=&w=&b=&t= | Config complete |
| `/surprise` | GET | - | Son aleatoire |
| `/communication` | GET | - | Son communication |
| `/ack` | GET | - | Son ack |
| `/ministop` | GET | - | Son ministop |
| `/taichi` | GET | - | Mouvement taichi |
| `/play` | GET | u=url | Jouer audio URL |
| `/sleep` | GET | - | Veille |
| `/wakeup` | GET | - | Reveil |
| `/stop` | GET | - | Stop tout |
| `/reboot` | GET | - | Redemarrage |
| `/forth` | GET/POST | c=code Forth | Execute code Forth arbitraire |

---

## Controle depuis Home Assistant

Le projet integre une configuration Home Assistant complete dans `homeassistant/`.

### 2 REST commands suffisent

```yaml
# Exemple: dire un message
- action: rest_command.nabaztag_api
  data:
    endpoint: say
    query: "t=Bonjour le monde"

# Exemple: oreille gauche
- action: rest_command.nabaztag_api
  data:
    endpoint: left
    query: "p=5&d=0"

# Exemple: controler les 4 flags firmware
- action: rest_command.nabaztag_autocontrol
  data:
    clock: "1"
    halftime: "0"
    surprise: "1"
    taichi: "1"
```

Voir `homeassistant/nabaztag/nabaztag_commands.yaml` pour la liste complete des 25 endpoints supportes.

### REST sensors disponibles

| Sensor | Endpoint | Attributs | Scan |
|--------|----------|-----------|------|
| `sensor.nabaztag_status` | `/status` | sleep_state, wake_up, go_to_bed, language, rev | 120s |
| `sensor.nabaztag_firmware_autostatus` | `/autostatus` | clock, halftime, surprise, taichi | 60s |

### Fichiers de configuration

| Fichier | Contenu |
|---------|---------|
| `nabaztag_commands.yaml` | 2 REST commands generiques |
| `nabaztag_automations.yaml` | 4 automations (reconnexion, LEDs, trafic, firmware) |
| `nabaztag_scripts.yaml` | 12 scripts (restore LEDs, toggles, oreilles, parole...) |
| `nabaztag_inputs.yaml` | 18 helpers (IP, message, flags, horaires...) |
| `nabaztag_life.yaml` | 10 scripts Life + 5 automations |
| `nabaztag_sensors.yaml` | 2 REST sensors (/status, /autostatus) |
| `lovelace/` | 3 cartes Lovelace (principal, config, guide LEDs) |

---

## Automatismes firmware (4 drapeaux)

Le firmware integre 4 comportements autonomes, controlables depuis HA:

| Variable Forth | Cle /autocontrol | Defaut | Declencheur |
|---------------|-------------------|--------|-------------|
| `autoclock-enabled` | c | 1 (ON) | `hooks.forth` — heure pile |
| `autohalftime-enabled` | h | 1 (ON) | `hooks.forth` — demi-heure |
| `autosurprise-enabled` | s | 1 (ON) | `crontab.forth` — aleatoire |
| `autotaichi-enabled` | t | 1 (ON) | `crontab.forth` — frequence configurable |

Chaque flag a son `input_boolean` dans HA (`nabaztag_firmware_clock`, etc.)
et son toggle est automatiquement sync avec le firmware via l'automation
`nabaztag_firmware_toggle`.

---

## Nabaztag Life (HA pilote)

Les 10 scripts Life sont pilotes par HA (pas par le firmware):

- Blagues, annonce meteo/trafic, etirement, baillement, danse oreilles
- 3 actions aleatoires par heure (2 horaires definis + 1 heure pleine)
- Desactivable via `input_boolean.nabaztaglife`

---

## Fichiers modifies (vs firmware original)

| Fichier | Modification |
|---------|-------------|
| `vl/config.forth` | 4 variables auto-control + auth desactivee |
| `vl/hooks.forth` | Verification drapeaux clock/halftime + TTS Piper |
| `vl/crontab.forth` | Verification drapeaux surprise/taichi |
| `firmware/srv/http_server.mtl` | /autocontrol, /autostatus, fixes HTTP |
| `firmware/net/ntp.mtl` | Bug fix: soustraction uptime retiree |
| `firmware/audio/audiolib.mtl` | Buffers: 64KB/512KB |
| `firmware/utils/url.mtl` | url_encode/url_decode pour TTS |
| `firmware/utils/config.mtl` | Francais par defaut |
| `firmware/protos/ntp_protos.mtl` | Serveur NTP IP fixe |
| `scripts/preproc.pl` | Timezone Europe/Paris |

---

## Installation du proxy TTS

### Deploiement

```bash
# Installer les dependances
apt install ffmpeg espeak-ng python3-pip

# Copier et lancer
python3 tts_server.py --port 6790
```

### Variables d'environnement

Voir `.env.example` pour toutes les options configurables.

---

## Compilation du firmware

```bash
# Compiler le compilateur MTL
make compiler

# Compiler le firmware (produit vl/bc.jsp)
make firmware
```

---

## Structure du projet

```
/
├── vl/                          # Forth files (web UI + config + hooks)
├── firmware/                    # MTL source (http_server, ntp, audio...)
├── scripts/                     # Preprocessing + compilation
├── homeassistant/               # Home Assistant configuration
│   ├── nabaztag/                # Commands, automations, scripts, inputs...
│   └── lovelace/                # Dashboard cards
├── tts_server.py                # Serveur TTS Python (Piper + FFmpeg)
├── piper_tts_stream.py          # Proxy TTS stream
├── .env.example                 # Configuration exemple
├── CHANGELOG.md
├── README.md
└── Makefile                     # Build system
```

---

## Depot GitHub

```
https://github.com/jsapede/nabaztag-piper
→ Fork de andreax79/ServerlessNabaztag
```

Voir `CHANGELOG.md` pour l'historique complet des modifications.
