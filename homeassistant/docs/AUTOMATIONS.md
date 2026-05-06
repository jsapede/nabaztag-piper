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
sensor.waze_trajet_domicile_travail → nabaztag_update_traffic_from_waze → input_number.nabaztag_traffic
device_tracker.nmap_nabaztag → nabaztag_online → rest_command.nabaztag_setup
```

### Conditions globales

> Le **réveil et le coucher** sont gérés nativement par le firmware via les variables `wake-up-at` et `go-to-bed-at` configurées dans `/setup`. Les heures sont paramétrables depuis HA via `input_number.nabaztag_wake_hour` et `input_number.nabaztag_sleep_hour`. Aucune automation HA supplémentaire n'est nécessaire.

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

**Conditions**: Aucune (s'exécute toujours)

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
1. Envoie `/setup` avec les paramètres HA actuels
2. Exécute `script.nabaztag_restore_leds`
3. Envoie `/autocontrol` avec l'état des flags firmware
4. Delay 2 secondes
5. Pour chaque LED enabled = on, exécute le script correspondant

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