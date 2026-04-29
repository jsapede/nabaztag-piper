# Documentation Nabaztag - Automations

Ce fichier documente toutes les automatisations (automations) du système Nabaztag.

## Fichiers de configuration

- **Emplacement**: `/config/nabaztag/nabaztag_automations.yaml`
- **Type**: automation
- **Recharge**: `ha_reload_core(target="automations")` après modification

---

## Architecture générale

### Dépendances

```
input_number.nabaztag_wake_hour → nabaztag_sync_wake_time → input_datetime.nabaztag_wake_trigger → nabaztag_auto_wakeup
input_number.nabaztag_sleep_hour → nabaztag_sync_sleep_trigger → input_datetime.nabaztag_sleep_trigger → nabaztag_auto_sleep
sensor.waze_trajet_domicile_travail → nabaztag_update_traffic_from_waze → input_number.nabaztag_traffic
device_tracker.nmap_nabaztag → nabaztag_online → rest_command.nabaztag_setup
```

### Conditions globales

Toutes les automations liées au "Nabaztag Life" vérifient que `input_boolean.nabaztaglife = on` avant de s'exécuter.

---

## Automations de réveil

### nabaztag_auto_wakeup

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_auto_wakeup |
| Alias | Nabaztag - Réveil automatique |
| Mode | **restart** (recommandé) |

**Note**: Le mode `restart` évite qu'une exécution bloque les suivantes. Si le réveil est déjà en cours et qu'une nouvelle heure arrives, l'exécution redémarre.

**Trigger**:
```yaml
- trigger: time
  at: input_datetime.nabaztag_wake_trigger
```

**Conditions**:
- `input_boolean.nabaztaglife = on`

**Actions**:
1. Exécute `script.nabaztag_wake_up`
   - Envoie `/wakeup`
   - Active `input_boolean.nabaztaglife`
   - Déclenche Taichi255
   - Positionne oreilles à 8
   - Dit "Bonjour ! Je me réveille pour une nouvelle journée !"

**Influence**: Réveille le Nabaztag à l'heure configurée chaque jour.

---

### nabaztag_sync_wake_time

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_sync_wake_time |
| Alias | Nabaztag - Sync heure réveil |
| Mode | **restart** |

**Note**: Mode restart pour éviter de louper une sync si l'heure change pendant l'exécution.

**Trigger**:
```yaml
- trigger: time_pattern
  minutes: "0"
```

**Actions**:
1. Lit `input_number.nabaztag_wake_hour`
2. Met à jour `input_datetime.nabaztag_wake_trigger` avec le format `HH:00:00`

**Influence**: Synchronise l'heure de réveil chaque heure pour que le trigger `nabaztag_auto_wakeup` fonctionne.

---

## Automations d'endormissement

### nabaztag_auto_sleep

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_auto_sleep |
| Alias | Nabaztag - Endormissement automatique |
| Mode | **restart** (recommandé) |

**Note**: Le mode `restart` évite qu'une exécution bloque les suivantes.

**Trigger**:
```yaml
- trigger: time
  at: input_datetime.nabaztag_sleep_trigger
```

**Conditions**:
- `input_boolean.nabaztaglife = on`

**Actions**:
1. Exécute `script.nabaztag_go_to_sleep`
   - Dit "Bonne soirée ! Je vais me reposer maintenant."
   - Active Taichi niveau 100
   - Positionne oreilles à 0
   - Éteint le nez
   - Envoie `/sleep`
   - Désactive `input_boolean.nabaztaglife`

**Influence**: Endort le Nabaztag à l'heure configurée chaque jour.

---

### nabaztag_sync_sleep_trigger

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_sync_sleep_trigger |
| Alias | Nabaztag - Sync heure coucher |
| Mode | **restart** |

**Note**: Mode restart pour éviter de louper une sync si l'utilisateur change l'heure pendant l'exécution.

**Trigger**:
```yaml
- trigger: state
  entity_id: input_number.nabaztag_sleep_hour
```

**Actions**:
1. Exécute `script.nabaztag_sync_sleep_time`
   - Lit `input_number.nabaztag_sleep_hour`
   - Met à jour `input_datetime.nabaztag_sleep_trigger`

**Influence**: Met à jour le trigger d'endormissement quand l'utilisateur change l'heure de coucher.

---

## Automations de gestion LEDs

### nabaztag_led_off_handler

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_led_off_handler |
| Alias | Nabaztag - Gestion LED OFF |
| Mode | **restart** |

**Note**: Si quelqu'un désactive une LED manuellement pendant l'exécution, le mode restart permet de relancer le processus.

**Trigger**:
```yaml
- trigger: state
  entity_id:
    - input_boolean.nabaztag_weather_enabled
    - input_boolean.nabaztag_traffic_enabled
    - input_boolean.nabaztag_pollution_enabled
    - input_boolean.nabaztag_nose_enabled
  to: "off"
```

**Actions**:
1. Exécute `script.nabaztag_reset_leds` (éteint toutes les LEDs)
2. Pour chaque LED enabled = on, exécute le script correspondant:
   - `nabaztag_weather_enabled` → `script.nabaztag_set_weather`
   - `nabaztag_traffic_enabled` → `script.nabaztag_set_traffic`
   - `nabaztag_pollution_enabled` → `script.nabaztag_set_pollution`
   - `nabaztag_nose_enabled` → `script.nabaztag_set_nose`

**Influence**: Maintient les LEDs actives même si l'utilisateur en désactive une manuellement. Évite les états incohérents.

---

## Automations de reconnexion réseau

### nabaztag_online

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_online |
| Alias | Nabaztag - Config après reconnexion |
| Mode | **restart** |

**Note**: Mode restart. Si le Nabaztag se reconnecte pendant la config, on relance.

**Trigger**:
```yaml
- trigger: state
  entity_id: device_tracker.nmap_nabaztag
  to: "home"
```

**Conditions**: Aucune (s'exécute même si nabaztaglife = off)

**Actions**:
1. Envoie `/setup` (configuration complète)
2. Exécute `script.nabaztag_reset_leds`
3. Pour chaque LED enabled = on, exécute le script correspondant

**Influence**: Restaure la configuration LEDs quand le Nabaztag se reconnecte au réseau après une perte de connexion.

**Prérequis**: Intégration `device_tracker.nmap` ou équivalent pour détecter la présence du Nabaztag.

---

## Automations de démarrage

### nabaztag_sync_all_at_startup

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_sync_all_at_startup |
| Alias | Nabaztag - Sync + Setup au démarrage |
| Mode | **restart** |

**Note**: Au démarrage de HA, si une config est déjà en cours, on peut la relancer.

**Trigger**:
```yaml
- trigger: homeassistant
  event: start
```

**Conditions**: Aucune

**Actions**:
1. Exécute `script.nabaztag_sync_sleep_time`
2. Exécute `script.nabaztag_sync_wake_time`
3. Envoie `/setup`
4. Exécute `script.nabaztag_reset_leds`
5. Delay 2 secondes
6. Pour chaque LED enabled = on, exécute le script correspondant

**Influence**: Au démarrage de Home Assistant, restaure la configuration complète du Nabaztag.

---

## Automations de mise à jour externe

### nabaztag_update_traffic_from_waze

| Propriété | Valeur |
|-----------|--------|
| ID | nabaztag_update_traffic_from_waze |
| Alias | Nabaztag - Mise à jour trafic Waze |
| Mode | **restart** |

**Note**: Si le trajet Waze change plusieurs fois rapidement, on prend la dernière valeur.

**Trigger**:
```yaml
- trigger: state
  entity_id: sensor.waze_trajet_domicile_travail
```

**Conditions**: Aucune

**Actions**:
1. Calcule le niveau de traffic:
   ```yaml
   traffic_level: >
     {% if duration < 20 %}0
     {% elif duration < 25 %}1
     {% elif duration < 30 %}2
     {% elif duration < 35 %}3
     {% elif duration < 45 %}4
     {% elif duration < 60 %}5
     {% else %}6
     {% endif %}
   ```
2. Met à jour `input_number.nabaztag_traffic` avec la valeur calculée

**Influence**: Met à jour automatiquement l'indicateur de traffic basé sur le temps de trajet Waze.

**Seuils de conversion**:

| Durée (min) | Valeur traffic |
|-------------|----------------|
| < 20 | 0 (fluide) |
| 20-25 | 1 |
| 25-30 | 2 |
| 30-35 | 3 |
| 35-45 | 4 |
| 45-60 | 5 |
| > 60 | 6 (bouchon) |

**Prérequis**: Capteur `sensor.waze_trajet_domicile_travail` (intégration Waze ou équivalent).

---

## Dépannage

### Problème: Le réveil ne se déclenche pas

1. Vérifier que `input_boolean.nabaztaglife = on`
2. Vérifier `input_number.nabaztag_wake_hour` (valeur entre 0-23)
3. Vérifier `input_datetime.nabaztag_wake_trigger` (mis à jour chaque heure)
4. Consulter les traces de `nabaztag_auto_wakeup`

### Problème: Les LEDs ne se rallument pas après extinction

1. Vérifier `nabaztag_led_off_handler` dans les traces
2. Vérifier les boolean `nabaztag_*_enabled`
3. Vérifier que les scripts `nabaztag_set_*` fonctionnent

### Problème: Le traffic ne se met pas à jour

1. Vérifier que `sensor.waze_trajet_domicile_travail` existe
2. Vérifier que le sensor a une valeur numérique
3. Consulter les traces de `nabaztag_update_traffic_from_waze`

### Problème: Pas de /setup après reconnexion

1. Vérifier `device_tracker.nmap_nabaztag` existe
2. Vérifier que le tracker détecte correctement "home"
3. Consulter les traces de `nabaztag_online`