# Documentation Nabaztag - Scripts

Ce fichier documente tous les scripts (actions unitaires) du système Nabaztag.

## Fichier de configuration

- **Emplacement**: `/config/nabaztag/nabaztag_scripts.yaml`
- **Type**: script
- **Recharge**: `ha_reload_core(target="scripts")` après modification

---

## Scripts de gestion des oreilles

### nabaztag_move_left_ear

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_move_left_ear |
| Alias | Nabaztag - Oreille gauche |

**Description**: Bouge l'oreille gauche selon la position définie dans `input_select.nabaztag_ear_position`.

**Entrée**: `input_select.nabaztag_ear_position` (0-16)

**Sequence**:
```yaml
- action: rest_command.nabaztag_left_ear
  data:
    position: "{{ states('input_select.nabaztag_ear_position') }}"
```

**Influence**: Positionne l'oreille gauche à la valeur du select. Doit être appelé manuellement ou via un bouton UI.

---

### nabaztag_move_right_ear

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_move_right_ear |
| Alias | Nabaztag - Oreille droite |

**Description**: Bouge l'oreille droite selon la position définie dans `input_select.nabaztag_ear_position`.

**Entrée**: `input_select.nabaztag_ear_position` (0-16)

**Sequence**:
```yaml
- action: rest_command.nabaztag_right_ear
  data:
    position: "{{ states('input_select.nabaztag_ear_position') }}"
```

---

### nabaztag_move_both_ears

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_move_both_ears |
| Alias | Nabaztag - Les deux oreilles |

**Description**: Bouge les deux oreilles successivement selon la position définie.

**Entrée**: `input_select.nabaztag_ear_position` (0-16)

**Sequence**:
1. Oreille gauche à la position
2. Delay 1 seconde
3. Oreille droite à la même position

---

## Scripts de gestion des LEDs

Ces scripts vérifient que le boolean correspondant est `on` avant d'exécuter la commande REST.

### nabaztag_set_nose

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_set_nose |
| Alias | Nabaztag - État du nez |

**Description**: Allume/éteint le nez LED selon la valeur du slider (uniquement si LED activée).

**Conditions**: `input_boolean.nabaztag_nose_enabled = on`

**Entrée**: `input_number.nabaztag_nose_state` (0-4)

**Sequence**:
```yaml
- condition: state
  entity_id: input_boolean.nabaztag_nose_enabled
  state: "on"
- action: rest_command.nabaztag_nose
  data:
    state: "{{ states('input_number.nabaztag_nose_state') | int }}"
```

---

### nabaztag_set_weather

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_set_weather |
| Alias | Nabaztag - Météo |

**Description**: Force manuellement l'affichage météo sur les LEDs. Le firmware récupère déjà la météo depuis Open-Meteo API via `weather.forth`, ce script permet uniquement de forcer une valeur spécifique depuis HA.

**Conditions**: `input_boolean.nabaztag_weather_enabled = on`

**Entrée**: `input_number.nabaztag_weather` (0-5)

**Sequence**:
```yaml
- condition: state
  entity_id: input_boolean.nabaztag_weather_enabled
  state: "on"
- action: rest_command.nabaztag_weather
  data:
    weather: "{{ states('input_number.nabaztag_weather') | int }}"
```

---

### nabaztag_set_traffic

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_set_traffic |
| Alias | Nabaztag - Trafic |

**Description**: Met à jour l'affichage du trafic sur les LEDs. Contrairement à la météo et la pollution, le **trafic n'est pas géré par le firmware** — il n'a pas d'API dédiée ; les données proviennent de **Waze** (ou autre source externe) et sont donc pilotées exclusivement depuis HA.

**Conditions**: `input_boolean.nabaztag_traffic_enabled = on`

**Entrée**: `input_number.nabaztag_traffic` (0-6), mis à jour automatiquement par l'automation `nabaztag_update_traffic_from_waze`

**Sequence**:
```yaml
- condition: state
  entity_id: input_boolean.nabaztag_traffic_enabled
  state: "on"
- action: rest_command.nabaztag_traffic
  data:
    traffic: "{{ states('input_number.nabaztag_traffic') | int }}"
```

---

### nabaztag_set_pollution

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_set_pollution |
| Alias | Nabaztag - Pollution |

**Description**: Force manuellement l'affichage de la pollution sur les LEDs. Comme la météo, le firmware récupère déjà la qualité de l'air depuis l'API Open-Meteo via `weather.forth` ; ce script permet de forcer une valeur.

**Conditions**: `input_boolean.nabaztag_pollution_enabled = on`

**Entrée**: `input_number.nabaztag_pollution` (0-10)

**Sequence**:
```yaml
- condition: state
  entity_id: input_boolean.nabaztag_pollution_enabled
  state: "on"
- action: rest_command.nabaztag_pollution
  data:
    pollution: "{{ states('input_number.nabaztag_pollution') | int }}"
```

---

## Scripts de parole et sons

### nabaztag_talk

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_talk |
| Alias | Nabaztag - Parler |

**Description**: Fait dire un message personnalisé au Nabaztag.

**Entrée**: `input_text.nabaztag_message`

**Sequence**:
```yaml
- action: rest_command.nabaztag_say
  data:
    message: "{{ states('input_text.nabaztag_message') }}"
```

**Utilisation UI**: Bouton avec champ texte dans Lovelace.

---

### nabaztag_ack

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_ack |
| Alias | Nabaztag - Son Ack |

**Description**: Joue le son "ACK" (bip de confirmation).

**Sequence**: `rest_command.nabaztag_ack`

---

### nabaztag_abort

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_abort |
| Alias | Nabaztag - Son Abort |

**Description**: Joue le son "ABORT" (bip d'erreur).

**Sequence**: `rest_command.nabaztag_abort`

---

### nabaztag_communication

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_communication |
| Alias | Nabaztag - Son Communication |

**Description**: Joue le son de communication.

**Sequence**: `rest_command.nabaztag_communication`

---

### nabaztag_ministop

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_ministop |
| Alias | Nabaztag - Son Ministop |

**Description**: Joue le son "MINISTOP".

**Sequence**: `rest_command.nabaztag_ministop`

---

## Scripts d'animation Taichi

### nabaztag_taichi

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_taichi |
| Alias | Nabaztag - Taichi |
| Champs | `intensity` (0-1000) |

**Description**: Déclenche le Taichi avec une intensité paramétrable. Script unifié remplaçant les anciens scripts séparés (stop/min/medium/max).

**Paramètres** :

| Valeur | Effet |
|--------|-------|
| 0 | Arrête l'animation |
| 40 | Intensité minimale |
| 80 | Intensité moyenne |
| 255 | Intensité maximale |
| 1000 | Mode répété (sans arrêt) |

**Sequence**: `/taichi?v={{ intensity }}`

**Utilisation** : Appel depuis une automation avec `data: { intensity: 80 }` ou depuis l'UI Lovelace avec un sélecteur numérique.

---

## Scripts de configuration

### nabaztag_apply_setup

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_apply_setup |
| Alias | Nabaztag - Appliquer Setup |

**Description**: Envoie la configuration complète au Nabaztag (latitude, longitude, langue, timezone, DST, heures).

**Sequence**:
1. Envoie `/setup` avec tous les paramètres
2. Crée une notification persistente "Configuration envoyée avec succès"

**Prérequis**: `input_text.nabaztag_ip_address`, `input_select.*`, `input_number.*`

---

### nabaztag_random_surprise

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_random_surprise |
| Alias | Nabaztag - Surprise aléatoire |

**Description**: Joue une animation/mood aléatoire (1-305).

**Sequence**:
1. Génère un nombre aléatoire entre 1 et 305
2. Envoie `/surprise?v=<nombre>`

---

### nabaztag_generate_random_action_times

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_generate_random_action_times |
| Alias | Générer heures actions aléatoires |

**Description**: Génère 2 heures aléatoires pour les actions Nabaztag Life (entre 9h et 21h).

**Sequence**:
1. Génère h1 aléatoire (9-21), m1 aléatoire (0-59)
2. Met à jour `input_datetime.nabaztag_random_action_time_1`
3. Génère h2 aléatoire (9-21), m2 aléatoire (0-59)
4. Met à jour `input_datetime.nabaztag_random_action_time_2`

---

## Scripts de gestion LEDs

### nabaztag_reset_leds

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_reset_leds |
| Alias | Nabaztag - Reset LEDs |

**Description**: Éteint toutes les LEDs du corps (weather, traffic, pollution) et le nez.

**Sequence**:
1. `/clear`
2. `/nose?v=0`

**Influence**: Utilisé lors des reconnexions, démarrages, et avant rallumage des LEDs.

---

## Dépannage

### Problème: Les scripts ne s'exécutent pas

1. Vérifier que le Nabaztag est en ligne (ping)
2. Vérifier l'adresse IP dans `input_text.nabaztag_ip_address`
3. Vérifier les traces du script dans HA

### Problème: Les LEDs ne respond pas aux scripts

1. Vérifier que le boolean enabled correspondant est `on`
2. Vérifier les valeurs des sliders (dans les ranges)
3. Tester manuellement avec curl: `curl http://<IP>/weather?v=1`

### Problème: Le script de parole ne fonctionne pas

1. Vérifier que le message n'est pas vide
2. Vérifier la longueur (< 255 caractères)
3. Vérifier que le timeout est suffisant (30s)