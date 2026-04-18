# Documentation Nabaztag - Index

Bienvenue dans la documentation complète de l'intégration Nabaztag pour Home Assistant.

---

## Vue d'ensemble

Ce projet permet de contrôler un Nabaztag (lapin connecté) via Home Assistant en utilisant le firmware [ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag).

### Fonctionnalités

- **Contrôle LEDs**: Météo, trafic, pollution, nez (affichage visuel)
- **Contrôle physique**: Oreilles (gauche/droite), parler, sons
- **Nabaztag Life**: Actions vivantes aléatoires (blagues, annonces, étirements)
- **Automatisations**: Réveil/coucher automatiques, pause déjeuner
- **Intégration Waze**: Mise à jour automatique du trafic basée sur le temps de trajet
- **Le Nabaztag qui parle**: Synthèse vocale via TTS intégré

---

## Structure des fichiers

```
nabaztag-home-assistant-2025/
├── nabaztag/
│   ├── nabaztag_inputs.yaml       # Inputs (sliders, booleans, selects)
│   ├── nabaztag_commands.yaml      # REST commands (API Nabaztag)
│   ├── nabaztag_scripts.yaml       # Scripts (actions unitaires)
│   ├── nabaztag_automations.yaml   # Automations (déclencheurs)
│   └── nabaztag_life.yaml          # Nabaztag Life (actions vivantes)
├── lovelace/
│   └── nabaztag_lovelace.yaml      # Interface utilisateur
├── docs/
│   ├── INDEX.md                    # Ce fichier
│   ├── INPUTS.md                   # Documentation des inputs
│   ├── REST_COMMANDS.md            # Documentation des REST commands
│   ├── SCRIPTS.md                  # Documentation des scripts
│   ├── AUTOMATIONS.md              # Documentation des automations
│   └── NABAZTAG_LIFE.md           # Documentation Nabaztag Life
└── README.md                       # Guide d'installation
```

---

## Flux de données

```
┌─────────────────────────────────────────────────────────────┐
│                     INPUTS (sliders)                        │
│  nabaztag_weather (0-5), nabaztag_traffic (0-6),           │
│  nabaztag_pollution (0-10), nabaztag_nose_state (0-4)      │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      SCRIPTS                                │
│  nabaztag_set_weather, nabaztag_set_traffic,                │
│  nabaztag_set_pollution, nabaztag_set_nose                 │
│  (vérifient boolean enabled avant d'exécuter)               │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   REST COMMANDS                              │
│  /weather, /traffic, /pollution, /nose, /say               │
│  → Nabaztag (IP: input_text.nabaztag_ip_address)            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌───────────────────────┐
                    │   NABAZTAG (firmware)  │
                    │  ├── LED RGB + nez    │
                    │  ├── Moteurs oreilles │
                    │  └── TTS (Piper) ←───Audio
                    └───────────────────────┘
```

---

## Le Nabaztag qui parle (TTS)

Comment ça marche:

1. **Home Assistant** envoie `/say?t=Bonjour` au Nabaztag
2. Le **Nabaztag** reçoit le message et le transmet à son serveur TTS interne (Piper)
3. Le **Nabaztag** reçoit l'audio et le joue automatiquement

**Vous n'avez rien à configurer** - tout est géré par le Nabaztag lui-même.
HA envoie juste le texte, le lapin s'occupe du reste.

---

## Dépendances externes

### Capteurs requis

- `sensor.waze_trajet_domicile_travail`: Temps de trajet domicile-travail (minutes)
  - Utilisé par: `nabaztag_update_traffic_from_waze` automation
  - Source: Intégration Waze ou équivalent

### Intégrations recommandées

- `device_tracker.nmap`: Détection de présence du Nabaztag sur le réseau

---

## Démarrage rapide

### 1. Configuration IP

Dans Home Assistant, aller dans **Paramètres → Appareils & Services → Entités** et chercher `input_text.nabaztag_ip_address`. Configurer l'adresse IP du Nabaztag.

### 2. Activer les LEDs

Aller dans l'interface Lovelace du Nabaztag et activer les boolean `nabaztag_weather_enabled`, `nabaztag_traffic_enabled`, etc.

### 3. Ajuster les sliders

Utiliser les sliders pour définir les valeurs initiales (0-5 pour météo, 0-6 pour trafic, etc.).

### 4. Tester

Cliquer sur les boutons de l'interface Lovelace pour tester les différentes fonctionnalités.

---

## Commandes utiles

### Recharger la configuration

```bash
# Valider la configuration
ha_check_config

# Recharger tout
ha_reload_core(target="all")

# Recharger spécifiquement
ha_reload_core(target="automations")
ha_reload_core(target="scripts")
ha_reload_core(target="core")
```

### Vérifier les entités

```bash
# Liste des entités Nabaztag
ha_search_entities(query="nabaztag")
```

---

## Dépannage global

### Le Nabaztag ne répond pas

1. Vérifier l'adresse IP: `input_text.nabaztag_ip_address`
2. Tester la connectivité: `ping <IP>`
3. Tester une commande: `curl http://<IP>/ack`

### Erreur 401 (Unauthorized)

Si vous voyez des erreurs 401 dans les traces d'automations:

1. Le Nabaztag nécessite une authentification HTTP
2. **Solution**: Désactiver l'authentification dans le firmware
   - Modifier le fichier `config.forth` du firmware
   - Commenter les lignes `username` et `md5-password`
   - Recompiler et-flash le firmware
3. Plus de détails dans [andreax79/ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag)

### Les LEDs ne s'affichent pas

1. Vérifier les boolean `nabaztag_*_enabled`
2. Vérifier les valeurs des sliders
3. Recharger les scripts

### Pas d'actions aléatoires

1. Vérifier `input_boolean.nabaztaglife = on`
2. Vérifier les automations dans les traces
3. Vérifier les heures aléatoires dans `input_datetime.nabaztag_random_action_time_*`

---

## Glossaire

| Terme | Description |
|-------|-------------|
| **Input** | Entité HA qui stocke une valeur (slider, boolean, texte) |
| **REST Command** | Commande HTTP vers le Nabaztag |
| **Automation** | Ensemble de règles qui déclenchen t des actions |
| **Script** | Séquence d'actions prédéfinie |
| **Nabaztag Life** | Système d'actions vivantes aléatoires |
| **Boolean** | Interrupteur on/off |
| **Slider** | Input numérique avec curseur |

---

## Annexe: Valeurs de référence

### nabaztag_weather (0-5)

| Valeur | LED | Description |
|--------|-----|-------------|
| 0 | Vert | Ciel dégagé |
| 1 | Jaune clair | Partiellement nuageux |
| 2 | Gris | Brouillard |
| 3 | Bleu | Pluie |
| 4 | Blanc | Neige |
| 5 | Rouge | Orage |

### nabaztag_traffic (0-6)

| Valeur | Trajet | Description |
|--------|--------|-------------|
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
| 0-2 | Excellent/Bonne |
| 3-4 | Acceptable/Médiocre |
| 5-6 | Mauvaise |
| 7-10 | Très mauvaise/Alerte max |

### nabaztag_nose_state (0-4)

| Valeur | Effet |
|--------|-------|
| 0 | Éteint |
| 1-4 | Intensité/couleur croissante |

---

## Liens externes

- [Firmware ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag)
- [Discussion Home Assistant](https://community.home-assistant.io/t/nabaztag-tag-the-smart-rabbit-is-back/41696)
- [Forum Nabaztag](https://nabaztag.forumactif.fr)

---

*Documentation générée pour l'intégration Nabaztag Home Assistant*