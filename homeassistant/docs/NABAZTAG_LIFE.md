# Documentation Nabaztag - Nabaztag Life

Ce fichier documente le système "Nabaztag Life" - les actions vivantes, aleatoires et les scripts de parole.

## Fichiers de configuration

- **Emplacement**: `/config/nabaztag/nabaztag_life.yaml`
- **Type**: automation + script
- **Recharge**: `ha_reload_core(target="automations")` et `ha_reload_core(target="scripts")` après modification

---

## Concept Nabaztag Life

Le "Nabaztag Life" est un système d'actions vivantes qui donne de la personalite au Nabaztag quand il est eveille (`input_boolean.nabaztaglife = on`).

**Caracteristiques**:
- Actions aleatoires aux heures definies (2 fois par heure)
- Annonce de l'heure aux heures pleines
- Pause/dejeuner a 12h30 et 13h30
- 10 types d'actions differentes dans le pool aleatoire

---

## Automations Nabaztag Life

### nabaztag_generate_action_times

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_generate_action_times |
| Alias | Nabaztag - Generer heures actions |
| Mode | single |

**Trigger**:
```yaml
- trigger: time_pattern
  hours: /1
```

**Conditions**:
- `input_boolean.nabaztaglife = on`

**Actions**:
1. Execute `script.nabaztag_generate_random_action_times`
   - Genere 2 heures aleatoires entre 9h et 21h
   - Met a jour `input_datetime.nabaztag_random_action_time_1`
   - Met a jour `input_datetime.nabaztag_random_action_time_2`

**Influence**: Definit quand le lapin fait une action aleatoire chaque heure.

---

### nabaztag_random_actions_time_1 / _time_2

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_random_actions_time_1, nabaztag_random_actions_time_2 |
| Alias | Nabaztag - Action aleatoire 1/2 |
| Mode | single |

**Trigger**:
```yaml
- trigger: time
  at: input_datetime.nabaztag_random_action_time_1  # ou _time_2
```

**Conditions**:
- `input_boolean.nabaztaglife = on`
- Probabilite 1/3 (`{{ (range(1,4) | random) == 1 }}`)

**Actions**:
1. Execute `script.nabaztag_random_action`

**Influence**: Execute une action aleatoire aux heures generee. Probabilite de 33% pour eviter trop d'actions.

---

### nabaztag_hourly_action

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_hourly_action |
| Alias | Nabaztag - Action horaire |
| Mode | single |

**Trigger**:
```yaml
- trigger: time_pattern
  minutes: 0
```

**Conditions**:
- `input_boolean.nabaztaglife = on`

**Actions**:
1. Execute `script.nabaztag_announce_time`
2. Delay 5 secondes
3. Execute `script.nabaztag_random_action`

**Influence**: Annonce l'heure a chaque heure pleine + action aleatoire.

---

### nabaztag_lunch_break

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_lunch_break |
| Alias | Nabaztag - Pause dejeuner |
| Mode | single |

**Trigger**:
```yaml
- trigger: time
  at: "12:30:00"
```

**Conditions**:
- `input_boolean.nabaztaglife = on`

**Actions**:
1. Envoie `/say?t=C'est l'heure du dejeuner ! Bon appétit a tous !`

**Influence**: Annonce la pause dejeuner.

---

### nabaztag_back_from_lunch

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_back_from_lunch |
| Alias | Nabaztag - Retour dejeuner |
| Mode | single |

**Trigger**:
```yaml
- trigger: time
  at: "13:30:00"
```

**Conditions**:
- `input_boolean.nabaztaglife = on`

**Actions**:
1. Envoie `/say?t=J'espere que vous avez bien mange ! On reprend !`
2. Execute `script.nabaztag_stretch`

**Influence**: Annonce la fin de la pause + etirement.

---

## Scripts Nabaztag Life

### nabaztag_random_action

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_random_action |
| Alias | Nabaztag - Action aleatoire |

**Description**: Tire au sort une action parmis 10 possibilites et l'execute.

**Pool d'actions** (distribution uniforme):

| Numero | Action | Description |
|--------|--------|-------------|
| 1 | nabaztag_tell_joke | Raconte une blague |
| 2 | nabaztag_say_weather | Dit la meteo (conversion integer -> texte) |
| 3 | nabaztag_say_traffic | Dit le trafic (conversion integer -> texte) |
| 4 | nabaztag_say_pollution | Dit la pollution (conversion integer -> texte) |
| 5 | nabaztag_announce_time | Annonce l'heure |
| 6 | nabaztag_stretch | Fait un etirement |
| 7 | nabaztag_yawn | Baie |
| 8 | nabaztag_ear_dance | Danse des oreilles |
| 9 | nabaztag_random_sound | Joue un son aleatoire |
| 10 | nabaztag_surprise_action | Fait une surprise |

---

### nabaztag_tell_joke

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_tell_joke |
| Alias | Nabaztag - Raconter une blague |

**Description**: Raconte une blague aleatoire parmi 9 blagues predefiies.

**Sequence**:
1. Envoie `/communication`
2. Delay 1 seconde
3. Envoie `/say?t=<blague>`

**Blagues disponibles**:
1. "Pourquoi les plongeurs plongent-ils toujours en arrière et jamais en avant ? Parce que sinon ils tombent dans le bateau !"
2. "Que dit un escargot quand il croise une limace ? Regarde un nudiste !"
3. "Qu'est-ce qui est jaune et qui attend ? Jonathan !"
4. "Pourquoi les poissons n'aiment pas jouer au tennis ? Parce qu'ils ont peur du filet !"
5. "Comment appelle-t-on un chat tomber dans un pot de peinture le jour de Noël ? Un chat-mallow !"
6. "Que dit un informaticien quand il se noie ? F1 F1 !"
7. "Comment fait-on pour allumer un barbecue breton ? On utilise des breizh !"
8. "Qu'est-ce qui est transparent et qui sent la carotte ? Un pet de lapin !"
9. "Pourquoi Mickey Mouse ? Parce que Mario Bros !"

---

### nabaztag_say_weather

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_say_weather |
| Alias | Nabaztag - Dire la meteo |

**Description**: Lit `input_number.nabaztag_weather` (0-5) et convertit en phrase intelligible.

**Entree**: `input_number.nabaztag_weather` (0-5)

**Conversion integer -> texte**:

| Valeur | Message |
|--------|---------|
| 0 | "Le ciel est degage, il fait beau !" |
| 1 | "Le temps est partiellement nuageux." |
| 2 | "Il y a du brouillard, la visibilite est reduite." |
| 3 | "Il pleut actuellement, prevoyez un parapluie." |
| 4 | "Il neige dehors, attention aux routes glissantes." |
| 5 | "Attention, il y a de l'orage !" |

**Sequence**: Envoie `/say?t=<message>`

---

### nabaztag_say_traffic

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_say_traffic |
| Alias | Nabaztag - Dire le trafic |

**Description**: Lit `input_number.nabaztag_traffic` (0-6) et convertit en phrase.

**Entree**: `input_number.nabaztag_traffic` (0-6)

**Conversion integer -> texte**:

| Valeur | Message |
|--------|---------|
| 0 | "Circulation fluide partout, pas de probleme." |
| 1 | "Circulation legerement dense, tout va bien." |
| 2 | "Le trafic est modere, quelques ralentissements." |
| 3 | "La circulation est dense, prevoyez un peu de retard." |
| 4 | "Des embouteillages sont signales sur votre trajet." |
| 5 | "Le trafic est tres charge, evitez si possible." |
| 6 | "Bouchon important, restez chez vous si vous pouvez !" |

**Sequence**: Envoie `/say?t=<message>`

---

### nabaztag_say_pollution

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_say_pollution |
| Alias | Nabaztag - Dire la pollution |

**Description**: Lit `input_number.nabaztag_pollution` (0-10) et convertit en phrase.

**Entree**: `input_number.nabaztag_pollution` (0-10)

**Conversion integer -> texte**:

| Valeur | Message |
|--------|---------|
| 0 | "L'air est excellent, respirer a plein poumons !" |
| 1 | "La qualite de l'air est tres bonne." |
| 2 | "Air de bonne qualite, pas d'inquietude." |
| 3 | "Qualite de l'air acceptable, OK pour les activites." |
| 4 | "Air mediocre, les sensibles doivent limiter les efforts." |
| 5 | "Mauvaise qualite de l'air, portez un masque dehors." |
| 6 | "Tres mauvaise qualite de l'air, restez a l'interieur." |
| 7 | "Qualite de l'air tres degradee, evitez les sorties." |
| 8 | "Alerte pollution elevee, restez prudent." |
| 9 | "Pollution severe, restez autant que possible a l'interieur." |
| 10 | "Alerte maximum pollution, dangereux de sortir !" |

**Sequence**: Envoie `/say?t=<message>`

---

### nabaztag_announce_time

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_announce_time |
| Alias | Nabaztag - Annoncer l'heure |

**Description**: Annonce l'heure actuelle.

**Sequence**:
1. Envoie `/ack`
2. Delay 1 seconde
3. Envoie `/say?t=Il est <HH> heures <MM>`

---

### nabaztag_stretch

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_stretch |
| Alias | Nabaztag - S'etirer |

**Description**: Fait un etirement avec annonce et animation Taichi.

**Sequence**:
1. Envoie `/say?t=<message_aleatoire>` (parmi 3)
2. Delay 5 secondes
3. Envoie `/taichi?v=255`
4. Delay 2 secondes
5. Envoie `/taichi?v=1000`

---

### nabaztag_yawn

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_yawn |
| Alias | Nabaztag - Bailler |

**Description**: Baie avec animation des oreilles.

**Sequence**:
1. Envoie `/say?t=<message_aleatoire>` (parmi 3)
2. Oreilles a position 0
3. Delay 2 secondes
4. Oreilles a position 16
5. Delay 1 seconde
6. Oreilles a position 8

---

### nabaztag_ear_dance

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_ear_dance |
| Alias | Nabaztag - Danse des oreilles |

**Description**: Bouge les deux oreilles de maniere aleatoire 3 fois.

**Sequence**:
1. Envoie `/communication`
2. Repete 3 fois:
   - Oreille gauche position aleatoire (0-10)
   - Oreille droite position aleatoire (0-10)
   - Delay 0.5 seconde
3. Oreilles a position 8

---

### nabaztag_random_sound

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_random_sound |
| Alias | Nabaztag - Son aleatoire |

**Description**: Joue un son aleatoire parmi 3.

**Sequence**:
1. Choix aleatoire (1-3):
   - 1: `/communication`
   - 2: `/ack`
   - 3: `/ministop`

---

### nabaztag_surprise_action

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_surprise_action |
| Alias | Nabaztag - Surprise |

**Description**: Execute une animation surprise aleatoire.

**Sequence**:
1. Execute `script.nabaztag_dance`
2. Delay 5 secondes
3. Envoie `/surprise?v=1` (mood aleatoire via nabaztag_dance)

---

## Script annexe

### nabaztag_announce_weather

| Propriete | Valeur |
|-----------|--------|
| ID | nabaztag_announce_weather |
| Alias | Nabaztag - Annoncer la meteo |

**Description**: Annonce la meteo basee sur `input_number.nabaztag_weather` (valeur 0-5 definie manuellement ou par le Nabaztag lui-meme).

**Differences avec `nabaztag_say_weather`**:
- Met a jour les LEDs et les oreilles selon la meteo (pas que la parole)
- Dit le message vocal base sur la valeur numerique

**Entree**: `input_number.nabaztag_weather` (0-5)

**Conversion LED valeur -> position oreilles**:

| Valeur | Position oreilles | Description |
|--------|-------------------|-------------|
| 0 | 0 | Ciel degage |
| 1 | 4 | Partiellement nuageux |
| 2 | 6 | Brouillard |
| 3 | 8 | Pluie |
| 4 | 7 | Neige |
| 5 | 5 | Orage |

**Note**: Ce script n'est pas dans le pool aleatoire, il doit etre appele manuellement.

---

## Depannage

### Probleme: Pas d'actions aleatoires

1. Verifier que `input_boolean.nabaztaglife = on`
2. Verifier `input_datetime.nabaztag_random_action_time_1/2`
3. Verifier les traces de `nabaztag_random_actions_time_1/2`

### Probleme: Le lapin ne parle pas

1. Verifier les REST commands (`/say`)
2. Verifier `input_text.nabaztag_message` n'est pas vide
3. Verifier le timeout des commandes (30s pour say)

### Probleme: Les messages ne correspondent pas aux valeurs

1. Verifier les valeurs dans `input_number.nabaztag_weather/traffic/pollution`
2. Verifier que les scripts lisent les bonnes valeurs
3. Verifier la conversion dans les templates Jinja

### Probleme: Pas d'annonce a midi

1. Verifier `nabaztag_lunch_break` dans les traces
2. Verifier l'heure systeme HA