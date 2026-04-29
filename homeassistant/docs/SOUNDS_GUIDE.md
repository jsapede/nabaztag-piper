# 🎵 Guide des sons et animations du Nabaztag

## Architecture des sons

Le firmware du Nabaztag embarque 2722 fichiers MP3 organisés dans `vl/config/`.
Ces fichiers sont servis par le serveur web firmware (static-web-server) et le Nabaztag
les télécharge à la volée via `play-url`.

```
http://<NABAZTAG_IP>/config/
├── clock/           ← Annonces horaires (heure pile)
├── clockall/        ← Annonces demi-heures
├── surprise/        ← Sons surprise aléatoires
├── weather/         ← Annonces météo (température, prévisions)
├── air/             ← Qualité de l'air
├── chor/            ← Chorégraphies (LEDs + moteurs)
├── animation/       ← Définitions des LEDs par service
├── respiration/     ← Son de respiration (veille)
└── signature/       ← Son de démarrage / jingle
```

---

## 1. Horloge (`clock/`) — heure pile

Déclenché par le firmware toutes les heures (via `hooks.forth`).
Structure :

```
clock/<langue>/<heure>/
├── 1.mp3   ← "Il est" (intro)
├── 2.mp3   ← "<heure>"
├── 3.mp3   ← "heures"
├── 4.mp3   ← "<minutes>"
├── 5.mp3   ← "minutes" / "et quart"
└── 6.mp3   ← "..." (fin de phrase)
```

**Appel depuis HA :**

```yaml
# Jouer l'annonce de 14 heures (français)
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/clock/fr/14/1.mp3"
```

---

## 2. Demi-heure (`clockall/`) — 30 minutes passées

Déclenché par le firmware à chaque demi-heure.

```
clockall/<langue>/
├── hg01.mp3  ← "Il est" (variante 1)
├── hg03.mp3  ← "Il est" (variante 2)
├── hg05.mp3  ← "et demie"
├── hg06.mp3  ← "et demie" (variante)
├── hg07.mp3  ← son de cloche
├── hg10.mp3  ← "Il est" (variante 3)
├── hg11.mp3  ← "demi-heure"
├── hg15.mp3  ← son long
├── hg16.mp3  ← son court
├── hg17.mp3  ← "ding"
└── hg18.mp3  ← "dong"
```

**Exemple HA :**

```yaml
# Son de cloche (demi-heure)
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/clock/fr/hg07.mp3"
```

---

## 3. Surprise (`surprise/`) — sons aléatoires

300 sons MP3 numérotés de `1.mp3` à `300.mp3`, déclenchés aléatoirement
par le firmware via `crontab.forth`. Durée : 0.5s à 3s chacun.

Ce sont divers bruitages : klaxons, sonneries, animaux, notes de musique, etc.

**Exemple HA :**

```yaml
# Jouer un son surprise au hasard
- variables:
    surprise_n: "{{ range(1, 301) | random }}"
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/surprise/fr/{{ surprise_n }}.mp3"
```

---

## 4. Météo (`weather/`) — annonces parlées

```
weather/<langue>/
├── -1.mp3 à -9.mp3   ← températures négatives
├── 0.mp3 à 50.mp3     ← températures positives
├── degree.mp3          ← "degrés"
├── today.mp3           ← "aujourd'hui"
├── tomorrow.mp3        ← "demain"
└── signature.mp3       ← jingle météo
```

Le firmware les utilise pour annoncer la météo vocale.

**Exemple HA :**

```yaml
# Annoncer "15 degrés aujourd'hui"
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/weather/fr/today.mp3"
- delay: "00:00:01"
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/weather/fr/15.mp3"
- delay: "00:00:01"
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/weather/fr/degree.mp3"
```

---

## 5. Qualité de l'air (`air/`) — pollution

```
air/<langue>/quality/
├── signature.mp3    ← jingle
├── good.mp3         ← "bonne"
├── bad.mp3          ← "mauvaise"
└── medium.mp3       ← "moyenne" (selon langue)
```

Utilisé avec `/config/weather/` pour les rapports de pollution.

---

## 6. Chorégraphies (`chor/`) — mouvements + LEDs

Fichiers `.chor` (binaires) qui pilotent les moteurs des oreilles et les LEDS :

| Fichier | Description |
|---------|-------------|
| `1.chor` | Chorégraphie 1 (danse classique) |
| `2.chor` | Chorégraphie 2 |
| `3.chor` | Chorégraphie 3 |
| `4.chor` | Chorégraphie 4 |
| `taichi.chor` | Mouvement Taichi (complet, 13KB) |
| `interactive_start.chor` | Début mode interactif |
| `interactive_error.chor` | Erreur mode interactif |
| `rfid_ok.chor` | RFID tag détecté |

**Appel depuis HA :**

```yaml
# Jouer une chorégraphie
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/chor/taichi.chor"

# Jouer une chorégraphie courte
- action: rest_command.nabaztag_api
  data:
    endpoint: play
    query: "u=http://{{ states('input_text.nabaztag_ip_address') }}/config/chor/1.chor"
```

---

## 7. Animations LEDs (`animation/`) — définitions JSON

Fichiers JSON définissant les couleurs et animations des LEDs pour chaque service :

| Fichier | Service | Palette |
|---------|---------|---------|
| `weather.json` | Météo | 6 niveaux (ciel → orage) |
| `traffic.json` | Trafic | 7 niveaux (fluide → bouchon) |
| `pollution.json` | Pollution | 10 niveaux |
| `stock.json` | Stock | 6 niveaux |
| `mail.json` | Mail | Alertes |

```json
// Extrait de weather.json : animation météo
{
  "palette": [ [100,200,50], ... ],
  "animations": [ ... ]
}
```

---

## 8. Sons unitaires — scripts d'animation HA

Voici des scripts HA prêts à l'emploi pour animer le Nabaztag :

### Réveil en douceur

```yaml
nabaztag_reveil:
  alias: "Nabaztag - Reveil en douceur"
  sequence:
    # Son de signature
    - action: rest_command.nabaztag_api
      data:
        endpoint: play
        query: "u={{ states('input_text.nabaztag_ip_address') }}/config/weather/fr/signature.mp3"
    - delay: "00:00:02"
    # Danse
    - action: rest_command.nabaztag_api
      data:
        endpoint: play
        query: "u={{ states('input_text.nabaztag_ip_address') }}/config/chor/taichi.chor"
```

### Annonce personnalisée météo + surprise

```yaml
nabaztag_annonce_matin:
  alias: "Nabaztag - Annonce matinale"
  sequence:
    - action: rest_command.nabaztag_api
      data:
        endpoint: play
        query: "u={{ states('input_text.nabaztag_ip_address') }}/config/clock/fr/{{ now().hour }}/1.mp3"
    - delay: "00:00:01"
    - action: rest_command.nabaztag_api
      data:
        endpoint: play
        query: "u={{ states('input_text.nabaztag_ip_address') }}/config/clock/fr/{{ now().hour }}/2.mp3"
    - delay: "00:00:01"
    - action: rest_command.nabaztag_api
      data:
        endpoint: play
        query: "u={{ states('input_text.nabaztag_ip_address') }}/config/surprise/fr/{{ range(1,301) | random }}.mp3"
```

### Soirée zen

```yaml
nabaztag_soiree:
  alias: "Nabaztag - Soiree zen"
  sequence:
    - action: rest_command.nabaztag_api
      data:
        endpoint: play
        query: "u={{ states('input_text.nabaztag_ip_address') }}/config/chor/taichi.chor"
```

---

## Structure des dossiers par langue

Les dossiers de langue supportés : `fr`, `en`, `de`, `es`, `it`, `uk`

| Dossier | `fr` | `en` | `de` | `es` | `it` | `uk` |
|---------|------|------|------|------|------|------|
| `clock/` | ✅ 24h | ✅  | ✅ | ✅ | ✅ | ✅ |
| `clockall/` | ✅ | — | — | — | — | — |
| `surprise/` | ✅ 300 sons | — | — | — | — | — |
| `weather/` | ✅ | — | — | — | — | — |
| `air/` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Référence : endpoint `play-url` du firmware

Le Nabaztag dispose de deux endpoints pour jouer du contenu audio :

| Endpoint | Usage | Type |
|----------|-------|------|
| `GET /play?u=URL` | Joue un MP3/WAV depuis une URL | Audio |
| `GET /mp3?v=URL` | Streaming MP3 depuis une URL | Audio |
| `play-chor` (interne) | Joue une chorégraphie `.chor` | Moteurs + LEDs |

Les scripts HA ci-dessus utilisent `/play?u=URL` via `rest_command.nabaztag_api`
avec `endpoint: play`.
