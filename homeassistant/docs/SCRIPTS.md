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

**Description**: Affiche la météo sur les LEDs du corps (uniquement si LED météo activée).

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

**Description**: Affiche le trafic sur les LEDs du corps (uniquement si LED trafic activée).

**Conditions**: `input_boolean.nabaztag_traffic_enabled = on`

**Entrée**: `input_number.nabaztag_traffic` (0-6)

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

**Description**: Affiche le niveau de pollution sur les LEDs du corps (uniquement si LED pollution activée).

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

### nabaztag_taichi_stop

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_taichi_stop |
| Alias | Nabaztag - Taichi Stop |

**Description**: Arrête l'animation Taichi.

**Sequence**: `/taichi?v=0`

---

### nabaztag_taichi_min

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_taichi_min |
| Alias | Nabaztag - Taichi Min |

**Description**: Animation Taichi intensité minimale (niveau 40).

**Sequence**:
1. `/taichi?v=40`
2. Delay 5 secondes
3. `/taichi?v=1000`

---

### nabaztag_taichi_medium

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_taichi_medium |
| Alias | Nabaztag - Taichi Moyen |

**Description**: Animation Taichi intensité moyenne (niveau 80).

**Sequence**:
1. `/taichi?v=80`
2. Delay 5 secondes
3. `/taichi?v=1000`

---

### nabaztag_taichi_max

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_taichi_max |
| Alias | Nabaztag - Taichi Max |

**Description**: Animation Taichi intensité maximale (niveau 255).

**Sequence**:
1. `/taichi?v=255`
2. Delay 5 secondes
3. `/taichi?v=1000`

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

### nabaztag_wake_up

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_wake_up |
| Alias | Nabaztag - Réveil |

**Description**: Fait réveiller le Nabaztag: son, LED, oreilles, annonce.

**Sequence**:
1. `/wakeup`
2. Delay 2 secondes
3. Active `input_boolean.nabaztaglife`
4. `/taichi?v=255`
5. Delay 3 secondes
6. Oreilles gauche et droite à position 8
7. Delay 1 seconde
8. Dit "Bonjour ! Je me réveille pour une nouvelle journée !"

**Influence**: Utilisé par l'automation de réveil automatique.

---

### nabaztag_go_to_sleep

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_go_to_sleep |
| Alias | Nabaztag - Endormissement |

**Description**: Fait dormir le Nabaztag: annonce, réduire LEDs, oreilles vers le bas, désactive nabaztaglife.

**Sequence**:
1. Dit "Bonne soirée ! Je vais me reposer maintenant."
2. Delay 3 secondes
3. `/taichi?v=100`
4. Delay 2 secondes
5. Oreilles gauche et droite à position 0
6. Nez à 0 (éteint)
7. Delay 2 secondes
8. `/sleep`
9. Désactive `input_boolean.nabaztaglife`

**Influence**: Utilisé par l'automation d'endormissement automatique.

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

## Scripts de synchronisation

### nabaztag_sync_sleep_time

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_sync_sleep_time |
| Alias | Nabaztag - Synchroniser heure coucher |

**Description**: Synchronise `input_number.nabaztag_sleep_hour` vers `input_datetime.nabaztag_sleep_trigger`.

**Sequence**:
1. Lit `input_number.nabaztag_sleep_hour`
2. Met à jour `input_datetime.nabaztag_sleep_trigger` avec le format `HH:00:00`

---

### nabaztag_sync_wake_time

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_sync_wake_time |
| Alias | Nabaztag - Synchroniser heure réveil |

**Description**: Synchronise `input_number.nabaztag_wake_hour` vers `input_datetime.nabaztag_wake_trigger`.

**Sequence**:
1. Lit `input_number.nabaztag_wake_hour`
2. Met à jour `input_datetime.nabaztag_wake_trigger` avec le format `HH:00:00`

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