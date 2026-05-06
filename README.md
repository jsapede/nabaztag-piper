# Nabaztag Piper — `nab-piper`

Nabaztag/tag serverless avec voix française naturelle (Piper TTS) et intégration Home Assistant.

## Fonctionnalités

- **Firmware** basé sur [ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag)
- **TTS français** via Piper (voix `fr_FR-siwis-medium`) — local, hors-ligne, < 1s
- **Post-traitement audio** : resampling 16kHz, filtre passe-haut 300Hz, amplification aigus +3dB
- **Deux pipelines** TTS : Piper (neuronal, recommandé) ou Coqui
- **Intégration Home Assistant** : weather/traffic/pollution push via telnet
- **Auto DST** : détection automatique des changements d'heure
- **Flags** autoclock, autohalftime, autosurprise, autotaichi
- **Versionnage** automatique YYYYMMDDHHMM dans le firmware

## Démarrage rapide

```bash
cd nabaztag-piper/install
./install.sh          # installation interactive
```

Le script installe Piper, compile le firmware, configure les services systemd et copie le package HA.

## Architecture

```
Lapin (192.168.0.58) ←→ Serveur (192.168.0.35:80)
  │                         │
  ├─ /say?t=texte           ├─ piper_tts_stream.py (TTS)
  ├─ /weather?v=N           ├─ static-web-server (firmware)
  ├─ /traffic?v=N           └─ conf.bin (config flash)
  ├─ /pollution?v=N
  └─ /setup?w=7&b=22
```

## Home Assistant

Le package HA se trouve dans `homeassistant/nabaztag/`. Il inclut :

- **Inputs** : heure réveil/coucher, météo/trafic/pollution, flags firmware
- **Automations** : Waze → trafic, Météo → weather, AQI → pollution, Auto DST
- **Sensors** : état firmware via telnet (30s), sync config, reboot detection
- **Scripts** : toggle LEDs, restore LEDs, taichi, oreilles
- **Lovelace** : carte de contrôle complète (v1.4.4)

## Commandes telnet disponibles

| Commande | Effet |
|----------|-------|
| `N 1 info-set` | Définit la météo (0-5) |
| `N 3 info-set` | Définit le trafic (0-6) |
| `N 7 info-set` | Définit la pollution (0-10) |
| `left-ear N 0 move-ear` | Bouge l'oreille gauche |
| `right-ear N 0 move-ear` | Bouge l'oreille droite |
| `N taichi` | Déclenche le taichi (N=0-255) |
| `wake-up` / `sleep` | Réveil / sommeil |

## Build

```bash
make firmware          # Compile le firmware (injection auto de la révision)
make deploy            # Déploie vers le serveur (nécessite DEPLOY_TARGET)
```

## Licence

MIT — voir [LICENSE](LICENSE) et [LICENSE-THIRD-PARTY.md](LICENSE-THIRD-PARTY.md).
