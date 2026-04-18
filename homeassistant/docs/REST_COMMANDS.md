# Documentation Nabaztag - REST Commands

Ce fichier documente toutes les commandes REST utilisées pour communiquer avec le Nabaztag via l'API HTTP du firmware ServerlessNabaztag.

## Fichier de configuration

- **Emplacement**: `/config/nabaztag/nabaztag_commands.yaml`
- **Type**: rest_command
- **Recharge**: `ha_reload_core(target="core")` après modification

---

## Configuration commune

Toutes les commandes utilisent l'adresse IP définie dans `input_text.nabaztag_ip_address`:

```yaml
url: "http://{{ states('input_text.nabaztag_ip_address') }}/endpoint"
method: get
timeout: 10
```

---

## Commandes de base

### wakeup

```http
GET http://<IP>/wakeup
```

**Description**: Réveille le Nabaztag (sort du mode veille).

**Timeout**: 30 secondes

**Utilisation**: Script `nabaztag_wake_up`

---

### sleep

```http
GET http://<IP>/sleep
```

**Description**: Met le Nabaztag en mode veille.

**Timeout**: 30 secondes

**Utilisation**: Script `nabaztag_go_to_sleep`

---

### say

```http
GET http://<IP>/say?t=<message_encoded>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| t | string | Message à dire (URL-encoded) |

**Description**: Fait parler le Nabaztag avec un message TTS.

Le Nabaztag gère le TTS lui-même - vous n'avez pas à vous soucier de l'IP du serveur vocal. HA envoie juste le texte, le lapin s'occupe du reste.

**Timeout**: 30 secondes

**Exemple**:
```
GET http://192.168.0.58/say?t=Il%20fait%20beau%20aujourd%27hui
```

**Utilisation**: Scripts `nabaztag_talk`, `nabaztag_announce_time`, speech scripts

---

## Commandes d'oreilles

### left_ear

```http
GET http://<IP>/left?p=<position>&d=<duration>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| p | int | Position (0-16, 0=devant, 8=milieu, 16=derrière) |
| d | int | Durée (0 = permanent) |

**Description**: Bouge l'oreille gauche à la position spécifiée.

**Timeout**: 10 secondes

**Utilisation**: Scripts `nabaztag_move_left_ear`, `nabaztag_ear_dance`, `nabaztag_stretch`

---

### right_ear

```http
GET http://<IP>/right?p=<position>&d=<duration>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| p | int | Position (0-16) |
| d | int | Durée (0 = permanent) |

**Description**: Bouge l'oreille droite à la position spécifiée.

**Timeout**: 10 secondes

**Utilisation**: Scripts `nabaztag_move_right_ear`, `nabaztag_ear_dance`

---

## Commandes LEDs

### nose

```http
GET http://<IP>/nose?v=<state>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| v | int | État du nez (0=éteint, 1-4=intensité croissante) |

**Description**: Contrôle le nez LED du Nabaztag.

**Timeout**: 10 secondes

**Utilisation**: Script `nabaztag_set_nose`

---

### weather

```http
GET http://<IP>/weather?v=<value>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| v | int | Valeur météo (0-5) |

**Description**: Affiche la météo sur les LEDs du corps (couleurs).

**Timeout**: 10 secondes

**Valeurs**:
| Valeur | Couleur LED | Description |
|--------|-------------|-------------|
| 0 | Vert | Ciel dégagé |
| 1 | Jaune clair | Partiellement nuageux |
| 2 | Gris | Brouillard |
| 3 | Bleu | Pluie |
| 4 | Blanc | Neige |
| 5 | Rouge | Orage |

**Utilisation**: Script `nabaztag_set_weather`, automation `nabaztag_announce_weather`

---

### traffic

```http
GET http://<IP>/traffic?v=<value>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| v | int | Valeur trafic (0-6) |

**Description**: Affiche le niveau de trafic sur les LEDs (bargraphe).

**Timeout**: 10 secondes

**Valeurs**: 0 = fluide → 6 = bouchon ( LEDs allumées progressivement)

**Utilisation**: Script `nabaztag_set_traffic`

---

### pollution

```http
GET http://<IP>/pollution?v=<value>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| v | int | Valeur pollution (0-10) |

**Description**: Affiche le niveau de pollution sur les LEDs (bargraphe).

**Timeout**: 10 secondes

**Valeurs**: 0 = excellent → 10 = alerte max

**Utilisation**: Script `nabaztag_set_pollution`

---

### clear

```http
GET http://<IP>/clear
```

**Description**: Éteint toutes les LEDs du corps (weather, traffic, pollution).

**Timeout**: 10 secondes

**Utilisation**: Script `nabaztag_reset_leds`

---

### nose_off

```http
GET http://<IP>/nose?v=0
```

**Description**: Éteint le nez LED (raccourci de `nose?v=0`).

**Timeout**: 10 secondes

**Utilisation**: Script `nabaztag_reset_leds`

---

## Commandes sonores

### ack

```http
GET http://<IP>/ack
```

**Description**: Joue le son "ACK" (bip de confirmation).

**Timeout**: 10 secondes

**Utilisation**: Script `nabaztag_ack`, `nabaztag_announce_time`

---

### abort

```http
GET http://<IP>/abort
```

**Description**: Joue le son "ABORT" (bip d'erreur).

**Timeout**: 10 secondes

**Utilisation**: Script `nabaztag_abort`

---

### communication

```http
GET http://<IP>/communication
```

**Description**: Joue le son de communication.

**Timeout**: 10 secondes

**Utilisation**: Scripts `nabaztag_tell_joke`, `nabaztag_ear_dance`, `nabaztag_random_sound`

---

### ministop

```http
GET http://<IP>/ministop
```

**Description**: Joue le son "MINISTOP".

**Timeout**: 10 secondes

**Utilisation**: Script `nabaztag_ministop`, `nabaztag_random_sound`

---

### surprise

```http
GET http://<IP>/surprise?v=<moods>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| v | int | Numéro de mood/animation (1-305) |

**Description**: Joue une animation/mood aléatoire ou spécifique.

**Timeout**: 10 secondes

**Valeurs**: 1-305 (différentes animations: sons, mouvements, lumières)

**Utilisation**: Script `nabaztag_surprise_action`, `nabaztag_random_surprise`

---

## Commandes d'animation

### taichi

```http
GET http://<IP>/taichi?v=<level>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| v | int | Niveau d'intensité (0=stop, 40=min, 80=moyen, 255=max) |

**Description**: Déclenche l'animation Taichi (mouvements d'oreilles). La valeur 1000 signifie "répéter indéfiniment".

**Timeout**: 10 secondes

**Valeurs**:
| Valeur | Effet |
|--------|-------|
| 0 | Arrête l'animation |
| 40 | Intensité minimale |
| 80 | Intensité moyenne |
| 255 | Intensité maximale |
| 1000 | Mode répété (sans arrêt) |

**Utilisation**: Scripts `nabaztag_taichi_stop`, `nabaztag_taichi_min`, `nabaztag_taichi_medium`, `nabaztag_taichi_max`, `nabaztag_stretch`

---

## Commandes de configuration

### setup

```http
GET http://<IP>/setup?j=<lat>&k=<lng>&l=<lang>&c=<city>&d=<dst>&w=<wake>&b=<sleep>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| j | float | Latitude (3 décimales) |
| k | float | Longitude (3 décimales) |
| l | string | Langue (fr, en, es, de, it) |
| c | string | Code ville (PAR, LON, NYC, TYO) |
| d | int | Heure d'été (0=non, 1=oui) |
| w | int | Heure de réveil (0-23) |
| b | int | Heure de coucher (0-23) |

**Description**: Envoie la configuration complète au Nabaztag (position, langue, timezone, heures).

**Timeout**: 30 secondes

**Exemple**:
```
GET http://192.168.0.58/setup?j=48.856&k=2.352&l=fr&c=PAR&d=1&w=7&b=23
```

**Utilisation**: Automations `nabaztag_online`, `nabaztag_sync_all_at_startup`, script `nabaztag_apply_setup`

---

## Dépannage

### Problème: Timeout sur les commandes

1. Vérifier que le Nabaztag est allumé et connecté au réseau
2. Vérifier l'adresse IP dans `input_text.nabaztag_ip_address`
3. Tester avec curl: `curl http://<IP>/ack`

### Problème: Le lapin ne parle pas

1. Vérifier que la commande `/say` fonctionne manuellement
2. Vérifier que le message n'est pas vide ou trop long (>255 caractères)
3. Vérifier la langue dans `input_select.nabaztag_language`

### Problème: Les LEDs ne changent pas

1. Vérifier que les valeurs envoyées sont dans les ranges corrects
2. Vérifier que le Nabaztag n'est pas en mode veille (`/sleep`)
3. Tester `/clear` pour réinitialiser les LEDs

### Problème: Erreur 401 (Unauthorized)

Si vous avez des erreurs 401 dans les logs:

1. **Cause**: Le Nabaztag nécessite une authentification HTTP Basic
2. **Solution**: Désactiver l'authentification dans le firmware
   - Dans le fichier `config.forth`, commenter les lignes `username` et `md5-password`
   - Recompiler le firmware et reflasher le Nabaztag
3. **Référence**: [ServerlessNabaztag GitHub](https://github.com/andreax79/ServerlessNabaztag)