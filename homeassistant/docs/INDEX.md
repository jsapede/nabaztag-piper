# Documentation Nabaztag — Index

Bienvenue dans la documentation de l'intégration Nabaztag pour Home Assistant, dans le cadre du projet **`nab-piper`** (fork de [ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) avec TTS local et intégration HA complète).

---

## Vue d'ensemble

L'intégration permet de contrôler un Nabaztag depuis Home Assistant via l'API REST embarquée du lapin.

- **Synthèse vocale locale** : Piper/Coqui
- **Package HA complet** : inputs, commandes REST, scripts, automatisations, Lovelace

### Architecture

```
┌──────────────────┐     commandes      ┌───────────────────┐
│  Home Assistant  │───── REST ────────▶│   Nabaztag v2     │
│  (automatismes)  │                    │  (serveur HTTP    │
└──────────────────┘                    │   embarqué)       │
                                        └────────┬──────────┘
                     ┌───────────────────────────┼──────────────────┐
                     │  firmware, *.forth,        │                  │
                     │  animations, config        │  /say?t=...      │
                     ▼                            ▼                  ▼
           ┌──────────────────┐         ┌──────────────────┐
           │  Serveur web      │         │  Serveur TTS     │
           │  (port 80)        │         │  (port 6790)     │
           │  vl/bc.jsp        │         │  piper/Coqui    │
           │  config/*.mp3     │         └──────────────────┘
           │  animations.json  │
           └──────────────────┘
```

---

## Fonctionnalités

### Contrôle LEDs
Météo (0-5), trafic (0-6), pollution (0-10), nez (0-4) — chaque service a son `input_boolean` d'activation et son `input_number` pour la valeur.

### Mise à jour automatique
- **Trafic** : Waze → `input_number.nabaztag_traffic` → telnet lapin
- **Météo** : weather.soucieu_en_jarrest → `sensor.meteo_niveau` → `input_number.nabaztag_weather` → telnet
- **Pollution** : AQI → `sensor.pollution_niveau` → `input_number.nabaztag_pollution` → telnet
- **DST** : détection automatique, `/setup` appliqué chaque heure

### Contrôle physique
Oreilles (gauche/droite avec position 0-16), nez, taichi.

### Automatismes firmware
4 flags (`autoclock`, `autohalftime`, `autosurprise`, `autotaichi`) contrôlables depuis HA. Les **template switches** lisent l'état réel du firmware via telnet.

---

## Structure des fichiers

```
config/
├── configuration.yaml               ← Ajouter : !include_dir_named nabaztag
└── nabaztag/
    ├── nabaztag_inputs.yaml         # Entités (text, select, number, boolean)
    ├── nabaztag_commands.yaml       # Commandes REST
    ├── nabaztag_sensors.yaml        # Capteur /status + templates
    ├── nabaztag_scripts.yaml        # Scripts
    ├── nabaztag_automations.yaml    # Automatisations
    └── nabaztag_telnet.yaml         # Capteur telnet étendu
```

---

## Démarrage rapide

### 1. Installer le package HA
Copier le dossier `homeassistant/nabaztag/` dans le répertoire `config/` de Home Assistant, puis ajouter dans `configuration.yaml` :

```yaml
homeassistant:
  packages: !include_dir_named nabaztag
```

### 2. Configurer l'IP du lapin
Dans HA, chercher `input_text.nabaztag_ip_address` et renseigner l'adresse IP du Nabaztag.

### 3. Activer les LEDs et flags
Dans l'interface Lovelace, activer les switches.

### 4. Tester
```bash
curl "http://<IP_LAPIN>/say?t=Bonjour"
```

---

## Valeurs de référence

### nabaztag_weather (0-5)

| Valeur | LED | Météo |
|--------|-----|-------|
| 0 | Vert | Ciel dégagé |
| 1 | Jaune | Partiellement nuageux |
| 2 | Gris | Brouillard |
| 3 | Bleu | Pluie |
| 4 | Blanc | Neige |
| 5 | Rouge | Orage |

### nabaztag_traffic (0-6)

| Valeur | Temps trajet | État |
|--------|-------------|------|
| 0 | < 20 min | Fluide |
| 1 | 20-25 min | Légèrement dense |
| 2 | 25-30 min | Modéré |
| 3 | 30-35 min | Dense |
| 4 | 35-45 min | Embouteillages |
| 5 | 45-60 min | Très chargé |
| 6 | > 60 min | Bouchon |

### nabaztag_pollution (0-10)

| Valeur | Qualité air |
|--------|-------------|
| 0-2 | Bonne |
| 3-4 | Médiocre |
| 5-6 | Mauvaise |
| 7-10 | Très mauvaise |

---

## Liens

- [Projet nab-piper](https://github.com/jsapede/nabaztag-piper)
- [Firmware ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) (fork d'origine)
