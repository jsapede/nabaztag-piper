# Guide des sons et animations du Nabaztag

## Architecture des sons

Le projet `nab-piper` met à disposition des fichiers MP3 dans `vl/config/`, servis par le **serveur web statique** (port 80 de la machine hôte). Le Nabaztag les télécharge à la volée via son endpoint `/play?u=URL` :

```
http://<SERVEUR_STATIC>/config/
├── clock/           ← Annonces horaires (heure pile)
├── clockall/        ← Annonces demi-heures (génériques)
├── surprise/        ← Sons surprise aléatoires
├── weather/         ← Annonces météo (températures, prévisions)
├── air/             ← Qualité de l'air
├── chor/            ← Chorégraphies (LEDs + moteurs)
├── animation/       ← Définitions des LEDs par service
├── respiration/     ← Son de respiration (veille)
└── signature/       ← Son de démarrage / jingle
```

> Les fichiers sont servis par le **serveur web statique** (`http://IP_SERVEUR:80/vl/config/...`), pas par le serveur embarqué du lapin. Le Nabaztag les télécharge via son endpoint `/play?u=URL`.

---

## 1. Horloge (`clock/`) — heure pile

Déclenché par le firmware toutes les heures (via `hooks.forth`).
Structure par heure (24h, 6 fichiers par heure) :

```
clock/<langue>/<heure>/
├── 1.mp3  ← intro (ex: "Il est")
├── 2.mp3  ← l'heure
├── 3.mp3  ← "heures"
├── 4.mp3  ← les minutes
├── 5.mp3  ← "minutes" / "et quart"
└── 6.mp3  ← fin de phrase
```

Disponible pour : `fr`, `es`, `uk`, `de`, `it` (24h × 6 fichiers = 144 MP3 par langue).

**Appel depuis HA :**

```yaml
# Jouer l'annonce pour 14 heures 30 (français)
- action: rest_command.nabaztag_play
  data:
    url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/clock/fr/14/1.mp3"
```

---

## 2. Demi-heure (`clockall/`) — annonces génériques

Déclenché par le firmware à chaque demi-heure. Contrairement à `clock/`, ce ne sont pas des annonces horaires spécifiques mais des phrases génériques sur le thème du temps (aléatoires parmi 11 fichiers).

```
clockall/<langue>/
├── 1.mp3  ← "C'est l'heure ! Enfin... c'est pas l'heure, c'est juste l'heure"
├── 2.mp3  ← "Au fait, c'est l'heure"
├── 3.mp3  ← "Tiens, j'ai quelque chose à dire. C'est l'heure !"
├── 4.mp3  ← chant rythmé "c'est l'heure"
├── 5.mp3  ← "Quelle heure il est ?"
├── 6.mp3  ← annonce sur l'heure
├── 7.mp3  ← "Il est exactement..."
├── 8.mp3  ← explication 1h = 60 minutes
├── 9.mp3  ← annonce courte
├── 10.mp3 ← annonce variante
└── 11.mp3 ← annonce variante
```

Disponible pour : `fr`, `es`, `uk` (11 fichiers génériques par langue, pas de référence à l'heure exacte).

> ⚠️ **Évolution** : les fichiers ont été renommés de `hg01.mp3`...`hg18.mp3` vers `1.mp3`...`11.mp3` (standardisation). Le code firmware génère désormais `11 random 1 +` pour sélectionner un fichier.

**Appel depuis HA :**

```yaml
# Jouer une annonce demi-heure au hasard
- variables:
    f: "{{ range(1, 12) | random }}"
- action: rest_command.nabaztag_play
  data:
    url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/clockall/fr/{{ f }}.mp3"
```

---

## 3. Surprise (`surprise/`) — bruitages aléatoires

290 sons MP3 numérotés de `1.mp3` à `290.mp3`, déclenchés aléatoirement
par le firmware via `crontab.forth`. Durée : 0.5s à 3s chacun.

Ce sont divers bruitages : klaxons, sonneries, animaux, notes de musique, etc.

Disponible pour : `fr`, `es`, `uk`, `de`, `it` (290 fichiers par langue).

> ⚠️ **Évolution** : le nombre a été ramené de 299+ (inégal selon les langues) à **290 fichiers homogènes** partout. Le firmware utilise `289 random 1 +`.

**Exemple HA :**

```yaml
# Jouer un son surprise au hasard
- variables:
    surprise_n: "{{ range(1, 291) | random }}"
- action: rest_command.nabaztag_play
  data:
    url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/surprise/fr/{{ surprise_n }}.mp3"
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

Le firmware les utilise pour annoncer la météo vocale. Ces fichiers sont **inchangés** par rapport au firmware d'origine.

Disponible pour : `fr`, `es`, `uk`, `de`, `it`.

**Exemple HA :**

```yaml
# Annoncer "15 degrés aujourd'hui"
- action: rest_command.nabaztag_play
  data:
    url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/weather/fr/today.mp3"
- delay: "00:00:01"
- action: rest_command.nabaztag_play
  data:
    url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/weather/fr/15.mp3"
- delay: "00:00:01"
- action: rest_command.nabaztag_play
  data:
    url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/weather/fr/degree.mp3"
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

Utilisé avec `/config/weather/` pour les rapports de pollution. Disponible en `fr`, `es`, `uk`, `de`, `it`.

---

## 6. Chorégraphies (`chor/`) — mouvements + LEDs

Fichiers `.chor` (binaires) qui pilotent les moteurs des oreilles et les LEDs :

| Fichier | Description |
|---------|-------------|
| `taichi.chor` | Mouvement Taichi (complet, 13KB) |
| `1.chor` à `4.chor` | Chorégraphies diverses |
| `interactive_start.chor` | Début mode interactif |
| `interactive_error.chor` | Erreur mode interactif |
| `rfid_ok.chor` | RFID tag détecté |

**Appel depuis HA :**

```yaml
# Jouer une chorégraphie taichi
- action: rest_command.nabaztag_play
  data:
    url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/chor/taichi.chor"
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

---

## 8. Sons unitaires — scripts d'animation HA

Voici des scripts HA prêts à l'emploi pour animer le Nabaztag :

### Réveil en douceur

```yaml
nabaztag_reveil:
  alias: "Nabaztag - Reveil en douceur"
  sequence:
    - action: rest_command.nabaztag_play
      data:
        url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/weather/fr/signature.mp3"
    - delay: "00:00:02"
    - action: rest_command.nabaztag_play
      data:
        url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/chor/taichi.chor"
```

### Annonce matinale

```yaml
nabaztag_annonce_matin:
  alias: "Nabaztag - Annonce matinale"
  sequence:
    - action: rest_command.nabaztag_play
      data:
        url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/clock/fr/{{ now().hour }}/1.mp3"
    - delay: "00:00:01"
    - action: rest_command.nabaztag_play
      data:
        url: "http://{{ states('input_text.nabaztag_ip_address') }}/play?u=http://<IP_SERVEUR>/config/surprise/fr/{{ range(1, 291) | random }}.mp3"
```

---

## Structure des dossiers par langue

Langues supportées : `fr`, `es`, `uk`, `de`, `it`

| Dossier | `fr` | `es` | `uk` | `de` | `it` | Description |
|---------|------|------|------|------|------|-------------|
| `clock/` | ✅ 24h×6 | ✅ 24h×6 | ✅ 24h×6 | ✅ 24h×6 | ✅ 24h×6 | 6 MP3 par heure |
| `clockall/` | ✅ 11 | ✅ 11 | ✅ 11 | — | — | Annonces génériques |
| `surprise/` | ✅ 290 | ✅ 290 | ✅ 290 | ✅ 290 | ✅ 290 | Bruitages aléatoires |
| `weather/` | ✅ | ✅ | ✅ | ✅ | ✅ | Annonces météo |
| `air/` | ✅ | ✅ | ✅ | ✅ | ✅ | Qualité de l'air |

---

## Référence : endpoint `/play` du firmware

Le Nabaztag dispose d'un endpoint pour jouer du contenu audio depuis une URL distante :

| Endpoint | Usage | Type |
|----------|-------|------|
| `GET /play?u=URL` | Joue un MP3/WAV/chor depuis une URL | Audio + chorégraphie |

Les scripts HA ci-dessus utilisent `/play?u=URL` via `rest_command.nabaztag_play` pour envoyer l'URL complète au lapin. Ce dernier télécharge le fichier depuis le **serveur web statique** et le joue.
