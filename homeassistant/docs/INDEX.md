# Documentation Nabaztag — Index

Bienvenue dans la documentation de l'intégration Nabaztag pour Home Assistant, dans le cadre du projet **`nab-piper`** (fork de [ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) avec TTS local, firmware étendu et intégration HA complète).

---

## Vue d'ensemble

L'intégration permet de contrôler un Nabaztag depuis Home Assistant via l'API REST embarquée du lapin. Le projet `nab-piper` y ajoute :

- **Synthèse vocale locale** : Piper/Coqui au lieu de Google Translate
- **4 flags firmware** (`/autocontrol`) : activer/désactiver les automatismes du lapin
- **Package HA complet** : inputs, commandes REST, scripts, automatisations, Lovelace
- **Nabaztag Life** : actions aléatoires pour rendre le lapin vivant

### Architecture

```
┌──────────────────┐     commandes      ┌───────────────────┐
│  Home Assistant  │───── REST ────────▶│   Nabaztag v2     │
│  (automatismes)  │                    │  (serveur HTTP    │
└──────────────────┘                    │   embarqué)       │
                                        └────────┬──────────┘
                     ┌────────────────────────────┼─────────────────┐
                     │  firmware, *.forth, MP3,   │                 │
                     │  animations, config        │  /say?t=...     │
                     ▼                            ▼                 ▼
           ┌──────────────────┐         ┌──────────────────┐
           │  Serveur web      │         │  Serveur TTS     │
           │  (port 80)        │         │  (port 6790)     │
           │  vl/bc.jsp        │         │  piper/Coqui    │
           │  config/*.mp3     │         └──────────────────┘
           │  animations.json  │
           └──────────────────┘
```

- **Home Assistant** dialogue directement avec le serveur HTTP du lapin
- **Le lapin** télécharge ses ressources (firmware, MP3, animations) depuis le serveur web statique
- **Le lapin** appelle le serveur TTS pour la synthèse vocale

---

## Fonctionnalités

### Contrôle LEDs
Météo, trafic, pollution, nez — chaque service a son `input_boolean` d'activation et son `input_number` pour la valeur, le tout visible dans le tableau de bord Lovelace.

### Contrôle physique
Oreilles (gauche/droite avec position 0-16), nez (5 états), stop, reboot.

### Synthèse vocale (TTS)
Le lapin parle via `GET /say?t=<texte>`. Le message est transmis au serveur TTS local qui génère un WAV 16kHz via Piper (ou Coqui) et le retourne directement au lapin.

### Automatismes firmware (nouveau dans `nab-piper`)
4 flags (`autoclock`, `autohalftime`, `autosurprise`, `autotaichi`) contrôlables depuis HA via l'endpoint `/autocontrol?c=1&h=0&s=1&t=1`. Les **template switches** (`switch.nabaztag_firmware_*`) lisent l'état réel du firmware via telnet — plus de mode optimiste : le switch affiche ce que le lapin a vraiment en mémoire.

> **Note** : la communication telnet se fait via Python sockets avec `\r\n` (RFC Telnet) — aucun binaire externe (`nc`, `netcat`) n'est requis.

### Nabaztag Life
Script qui pioche aléatoirement parmi 10 actions (blague, météo, trafic, étirement, danse des oreilles, bâillement, etc.) pour rendre le lapin réactif et vivant.

### Automatisations
- Reconnexion automatique au démarrage HA ou au retour du lapin
- Synchronisation des flags firmware
- Gestion des LEDs par interrupteur

---

## Structure des fichiers

```
config/
├── configuration.yaml               ← Ajouter : !include_dir_named nabaztag
└── nabaztag/
    ├── nabaztag_inputs.yaml         # Entités (text, select, number, boolean)
    ├── nabaztag_commands.yaml       # Commandes REST
    ├── nabaztag_sensors.yaml        # Capteur /status
    ├── nabaztag_scripts.yaml        # Scripts
    ├── nabaztag_automations.yaml    # Automatisations
    └── nabaztag_life.yaml           # Actions vivantes aléatoires
```

---

## Démarrage rapide

### 1. Installer le package HA
Copier le dossier `homeassistant/nabaztag/` dans le répertoire `config/` de Home Assistant, puis ajouter dans `configuration.yaml` :

```yaml
homeassistant:
  packages: !include_dir_named nabaztag
```

Recharger la configuration (`ha_reload_core(target="all")`).

### 2. Configurer l'IP du lapin
Dans HA, chercher `input_text.nabaztag_ip_address` et renseigner l'adresse IP du Nabaztag.

### 3. Activer les LEDs et les flags
Dans l'interface Lovelace, activer les switches :
- LEDs : `nabaztag_weather_enabled`, `nabaztag_traffic_enabled`, etc.
- Firmware : `nabaztag_firmware_clock`, `nabaztag_firmware_halftime`, etc.

### 4. Tester
```bash
# Faire parler le lapin
curl "http://<IP_LAPIN>/say?t=Bonjour"
```

---

## Commandes utiles

```bash
# Valider la configuration HA
ha_check_config

# Recharger tout (après modif des packages)
ha_reload_core(target="all")

# Voir toutes les entités Nabaztag
ha_search_entities(query="nabaztag")
```

---

## Dépannage

### Le Nabaztag ne répond pas
1. Vérifier `input_text.nabaztag_ip_address`
2. Tester : `ping <IP>`
3. Tester une commande : `curl http://<IP>/ack`

### Les LEDs ne s'affichent pas
1. Vérifier les boolean `nabaztag_*_enabled`
2. Vérifier les valeurs des sliders
3. Recharger les scripts

### Pas d'actions aléatoires
1. Vérifier `input_boolean.nabaztaglife = on`
2. Vérifier les heures dans `input_datetime.nabaztag_random_action_time_*`

---

## Glossaire

| Terme | Description |
|-------|-------------|
| **Input** | Entité HA qui stocke une valeur (slider, boolean, texte) |
| **REST Command** | Commande HTTP vers le serveur du Nabaztag |
| **Automation** | Règle déclenchée par un événement |
| **Script** | Séquence d'actions prédéfinie |
| **Nabaztag Life** | Système d'actions vivantes aléatoires |
| **Flag firmware** | Variable interne au firmware contrôlable via `/autocontrol` |

---

## Annexe : valeurs de référence

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

### nabaztag_nose_state (0-4)

| Valeur | Effet |
|--------|-------|
| 0 | Éteint |
| 1-4 | Intensité/couleur croissante |

---

## Liens

- [Projet nab-piper](https://github.com/jsapede/nabaztag-piper)
- [Firmware ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) (fork d'origine)
- [Guide des sons](SOUNDS_GUIDE.md)
- [Documentation Home Assistant](https://www.home-assistant.io/)
