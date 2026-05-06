# Documentation Nabaztag - Inputs

Ce fichier documente tous les inputs (entrées) utilisés par l'intégration Nabaztag dans Home Assistant.

## Fichiers de configuration

- **Emplacement**: `/config/nabaztag/nabaztag_inputs.yaml`
- **Type**: input_number, input_text, input_select, input_boolean, input_datetime
- **Recharge**: `ha_reload_core(target="core")` après modification

---

## Input Text

### nabaztag_ip_address

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Adresse IP Nabaztag |
| Type | input_text |
| Valeur initiale | 192.168.0.58 |
| Description | Adresse IP du Nabaztag sur le réseau local |

**Influence**: Toutes les REST commands utilisent cette valeur pour construire l'URL du Nabaztag. Si l'adresse est incorrecte, aucune commande ne fonctionnera.

**Exemple**: `http://192.168.0.58/wakeup`

---

### nabaztag_message

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Message à dire |
| Type | input_text |
| Valeur initiale | "Bonjour, je m'appelle Nabaztag" |
| Longueur max | 255 caractères |

**Influence**: Utilisé par le script `nabaztag_talk` pour faire parler le Nabaztag avec un message personnalisé via l'UI Lovelace.

---

## Input Select

### nabaztag_ear_position

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Position des oreilles |
| Type | input_select |
| Options | 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 |
| Valeur initiale | 5 |

**Influence**: Positionne les deux oreilles à la même valeur (0 = avant, 8 = milieu, 16 = arrière). Utilisée par les scripts de mouvement d'oreilles.

**Valeurs**: 0 (devant) → 16 (derrière), 8 = position neutre

---

### nabaztag_language

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Langue |
| Type | input_select |
| Options | fr, en, es, de, it |
| Valeur initiale | fr |

**Influence**: Envoyée au Nabaztag via la commande `/setup` pour la synthèse vocale (TTS).

---

### nabaztag_timezone_city

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Ville/Timezone |
| Type | input_select |
| Options | Europe/Paris, Europe/London, America/New_York, Asia/Tokyo |
| Valeur initiale | Europe/Paris |

**Influence**: Envoyée au Nabaztag via `/setup` pour l'horloge intégrée.

---

## Input Number (Sliders)

### nabaztag_weather

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Météo |
| Type | input_number |
| Min | 0 |
| Max | 5 |
| Step | 1 |
| Mode | slider |
| Valeur initiale | 1 |

**Influence**: Affiche la météo sur les LEDs du corps (uniquement si `nabaztag_weather_enabled = on`).

**Valeurs**:

| Valeur | Description LED | Message (nabaztag_say_weather) |
|--------|-----------------|-------------------------------|
| 0 | Ciel dégagé | "Le ciel est dégagé, il fait beau !" |
| 1 | Partiellement nuageux | "Le temps est partiellement nuageux." |
| 2 | Brouillard | "Il y a du brouillard, la visibilité est réduite." |
| 3 | Pluie | "Il pleut actuellement, prévoyez un parapluie." |
| 4 | Neige | "Il neige dehors, attention aux routes glissantes." |
| 5 | Orage | "Attention, il y a de l'orage !" |

---

### nabaztag_traffic

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Trafic |
| Type | input_number |
| Min | 0 |
| Max | 6 |
| Step | 1 |
| Mode | slider |
| Valeur initiale | 3 |

**Influence**: Affiche le niveau de trafic sur les LEDs (uniquement si `nabaztag_traffic_enabled = on`). Mise à jour automatique via automation Waze.

**Valeurs**:

| Valeur | Temps trajet | Message (nabaztag_say_traffic) |
|--------|--------------|------------------------------|
| 0 | < 20 min | "Circulation fluide partout, pas de problème." |
| 1 | 20-25 min | "Circulation légèrement dense, tout va bien." |
| 2 | 25-30 min | "Le trafic est modéré, quelques ralentissements." |
| 3 | 30-35 min | "La circulation est dense, prévoyez un peu de retard." |
| 4 | 35-45 min | "Des embouteillages sont signalés sur votre trajet." |
| 5 | 45-60 min | "Le trafic est très chargé, évitez si possible." |
| 6 | > 60 min | "Bouchon important, restez chez vous si vous pouvez !" |

**Automation**: `nabaztag_update_traffic_from_waze` convertit `sensor.waze_trajet_domicile_travail` (minutes) en valeur 0-6.

---

### nabaztag_pollution

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Pollution |
| Type | input_number |
| Min | 0 |
| Max | 10 |
| Step | 1 |
| Mode | slider |
| Valeur initiale | 3 |

**Influence**: Affiche le niveau de pollution sur les LEDs (uniquement si `nabaztag_pollution_enabled = on`).

**Valeurs**:

| Valeur | Qualité air | Message (nabaztag_say_pollution) |
|--------|-------------|---------------------------------|
| 0 | Excellent | "L'air est excellent, respirer à plein poumons !" |
| 1 | Très bonne | "La qualité de l'air est très bonne." |
| 2 | Bonne | "Air de bonne qualité, pas d'inquiétude." |
| 3 | Acceptable | "Qualité de l'air acceptable, OK pour les activités." |
| 4 | Médiocre | "Air médiocre, les sensibles doivent limiter les efforts." |
| 5 | Mauvaise | "Mauvaise qualité de l'air, portez un masque dehors." |
| 6 | Très mauvaise | "Très mauvaise qualité de l'air, restez à l'intérieur." |
| 7 | Très dégradée | "Qualité de l'air très dégradée, évitez les sorties." |
| 8 | Élevée | "Alerte pollution élevée, restez prudent." |
| 9 | Sévère | "Pollution sévère, restez autant que possible à l'intérieur." |
| 10 | Alerte max | "Alerte maximum pollution, dangereux de sortir !" |

---

### nabaztag_nose_state

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | État du nez |
| Type | input_number |
| Min | 0 |
| Max | 4 |
| Step | 1 |
| Mode | slider |
| Valeur initiale | 0 |

**Influence**: Contrôle le nez LED (uniquement si `nabaztag_nose_enabled = on`).

**Valeurs**: 0 = éteint, 1-4 = intensité/couleur croissante

---

### nabaztag_wake_hour

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Heure de réveil |
| Type | input_number |
| Min | 0 |
| Max | 23 |
| Step | 1 |
| Valeur initiale | 7 |

**Influence**: Heure de réveil envoyée au firmware via `/setup`. Le firmware gère le réveil automatique. Pas d'automation HA nécessaire.

---

### nabaztag_sleep_hour

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Heure de coucher |
| Type | input_number |
| Min | 0 |
| Max | 23 |
| Step | 1 |
| Valeur initiale | 23 |

**Influence**: Heure de coucher envoyée au firmware via `/setup`. Le firmware gère l'endormissement automatique. Pas d'automation HA nécessaire.

---

### nabaztag_taichi_freq

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Fréquence Taichi |
| Type | input_number |
| Min | 0 |
| Max | 255 |
| Step | 1 |
| Valeur initiale | 100 |

**Influence**: Fréquence de l'animation Taichi (mouvements d'oreilles). Envoyée au Nabaztag via `/setup?t=<valeur>`.

- 0 = désactivé
- 40 = intensité minimale
- 80 = intensité moyenne
- 255 = intensité maximale
- 100 = valeur par défaut (confortable)

---

## Input Boolean (Interrupteurs)

### nabaztag_daylight_saving
- `on`: Réveil automatique, actions aléatoires, pause déjeuner actifs
- `off`: Lapin en mode "dodo" (pas d'actions automatiques)

---

### nabaztag_weather_enabled

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | LED Météo |
| Type | input_boolean |
| Valeur initiale | on |
| Icône | mdi:weather-partly-cloudy |

**Influence**: Active/désactive l'affichage de la météo sur les LEDs du corps.

---

### nabaztag_traffic_enabled

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | LED Trafic |
| Type | input_boolean |
| Valeur initiale | off |
| Icône | mdi:traffic-light |

**Influence**: Active/désactive l'affichage du trafic sur les LEDs du corps.

---

### nabaztag_pollution_enabled

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | LED Pollution |
| Type | input_boolean |
| Valeur initiale | off |
| Icône | mdi:factory |

**Influence**: Active/désactive l'affichage de la pollution sur les LEDs du corps.

---

### nabaztag_nose_enabled

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | LED Nez |
| Type | input_boolean |
| Valeur initiale | off |
| Icône | mdi:led-on |

**Influence**: Active/désactive le nez LED.

---

### nabaztag_daylight_saving

| Propriété | Valeur |
|-----------|--------|
| Nom affiché | Heure d'été |
| Type | input_boolean |
| Valeur initiale | off |

**Influence**: Envoyée au Nabaztag via `/setup` pour l'ajustement horaire (DST).

---

## Switches Firmware (template switches depuis `nab-piper`)

Les 4 flags firmware (`autoclock`, `autohalftime`, `autosurprise`, `autotaichi`) sont désormais des **template switches HA** qui lisent **l'état réel du firmware** via le **sensor telnet** (interrogé toutes les 1s). Plus de mode optimiste : le switch affiche ce que le lapin a vraiment en mémoire, pas ce qu'on lui a demandé.

Les switches sont définis dans `nabaztag_sensors.yaml` :

| Switch HA | Variable Forth | Endpoint |
|-----------|---------------|----------|
| `switch.nabaztag_firmware_clock` | `_autoclock_enabled` | `/forth?c=1%20autoclock-enabled%20!` |
| `switch.nabaztag_firmware_halftime` | `_autohalftime_enabled` | `/forth?c=1%20autohalftime-enabled%20!` |
| `switch.nabaztag_firmware_surprise` | `_autosurprise_enabled` | `/forth?c=1%20autosurprise-enabled%20!` |
| `switch.nabaztag_firmware_taichi` | `_autotaichi_enabled` | `/forth?c=1%20autotaichi-enabled%20!` |

**Principe de fonctionnement :**
1. Le `command_line` sensor `sensor.nabaztag_telnet_status` interroge le telnet du lapin via le mot Forth `status-all` (8 valeurs en un appel compilé, ~800ms)
2. Les template binary_sensors lisent les attributs de ce sensor pour afficher l'état réel
3. Quand l'utilisateur toggle un input_boolean, l'automation envoie la commande telnet (`nab-telnet.py`), puis `homeassistant.update_entity` force le rafraîchissement du capteur
4. Le sensor HTTP `/status` passe en `scan_interval: 300` (5 min) — uniquement pour les données de configuration (langue, fuseau, version)

**Note :** la communication telnet utilise Python sockets standard avec `\r\n` (RFC Telnet) — aucun binaire externe n'est requis.
## Dépannage

### Problème: Le lapin ne répond pas

1. Vérifier `input_text.nabaztag_ip_address` - l'adresse IP doit être correcte
2. Vérifier que le Nabaztag est allumé et connecté au réseau
3. Tester avec `ping <adresse_ip>` depuis HA

### Problème: Les LEDs ne s'affichent pas

1. Vérifier que le boolean correspondant est `on` (ex: `nabaztag_weather_enabled`)
2. Vérifier la valeur du slider (ex: `nabaztag_weather` entre 0-5)
3. Recharger les scripts: `ha_reload_core(target="scripts")`

### Problème: Le trafic ne se met pas à jour

1. Vérifier que `sensor.waze_trajet_domicile_travail` existe et fonctionne
2. Vérifier l'automation `nabaztag_update_traffic_from_waze` dans les traces
3. Vérifier que `input_number.nabaztag_traffic` change bien

### Problème: Erreur 401 dans les automations

Si les commandes REST retournent 401:

1. L'authentification HTTP est activée sur le Nabaztag
2. Solution: désactiver dans le firmware (voir [INDEX.md](./INDEX.md))