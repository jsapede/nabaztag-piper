# Documentation Nabaztag - REST Commands

Ce fichier documente toutes les commandes REST utilisées pour communiquer avec le Nabaztag via l'API HTTP de son firmware embarqué (projet **`nab-piper`**).

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

**Utilisation**: Commande manuelle depuis HA ou script personnel

---

### sleep

```http
GET http://<IP>/sleep
```

**Description**: Met le Nabaztag en mode veille.

**Timeout**: 30 secondes

**Utilisation**: Commande manuelle depuis HA ou script personnel

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

Le lapin transmet le texte à son serveur TTS local (Piper, port 6790) qui génère le WAV et le retourne directement. Le serveur TTS est configuré dans le `.env` du projet `nab-piper` et tourne sur la machine hôte.

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

**Description**: Joue une animation/surprise aléatoire via le firmware (parmi 290 sons disponibles).

**Timeout**: 10 secondes

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
GET http://<IP>/setup?j=<lat>&k=<lng>&l=<lang>&c=<city>&d=<dst>&w=<wake>&b=<sleep>&u=<server_url>
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
| u | string | URL du serveur de ressources (mode serverless) |

**Description**: Envoie la configuration complète au Nabaztag (position, langue, timezone, heures, URL serveur).

**Timeout**: 30 secondes

**Exemple**:
```
GET http://192.168.0.58/setup?j=48.856&k=2.352&l=fr&c=PAR&d=1&w=7&b=23&u=http://192.168.1.100:80/vl/
```

**Utilisation**: Automations `nabaztag_online`, `nabaztag_sync_all_at_startup`, script `nabaztag_apply_setup`

---

### autocontrol (nouveau dans `nab-piper`)

```http
GET http://<IP>/autocontrol?c=<clock>&h=<halftime>&s=<surprise>&t=<taichi>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| c | int | Flag horloge (0=désactivé, 1=activé) |
| h | int | Flag demi-heure |
| s | int | Flag surprise |
| t | int | Flag taichi |

**Description**: Active ou désactive les automatismes internes du firmware en temps réel, sans redémarrage. Chaque flag correspond à un `input_boolean` dans HA, synchronisé automatiquement.

**Timeout**: 10 secondes

**Exemple**:
```
GET http://192.168.0.58/autocontrol?c=1&h=0&s=1&t=1
```

**Utilisation**: Automation `nabaztag_reconnexion`, switches firmware

---

### forth (nouveau dans `nab-piper`)

```http
GET http://<IP>/forth?c=<code_forth_encoded>
```

**Paramètres**:
| Paramètre | Type | Description |
|-----------|------|-------------|
| c | string | Code Forth à exécuter (URL-encoded) |

**Description**: Exécute du code Forth directement sur le firmware, permettant de modifier n'importe quelle variable interne (flags, langue, configuration...).

**Timeout**: 10 secondes

**Exemple**:
```
# Activer l'horloge
GET http://192.168.0.58/forth?c=1%20autoclock-enabled%20!
```

**Utilisation**: Switches firmware (synchro via `/forth` et `/autocontrol`)

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

Si l'authentification HTTP est activée dans le firmware, chaque requête doit inclure les credentials. Pour désactiver :
- Modifier `config.forth` et commenter les lignes `username` et `md5-password`
- Recompiler le firmware