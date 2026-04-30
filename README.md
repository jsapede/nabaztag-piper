# Nabaztag Serverless — `nab-piper`

## Un Nabaztag autonome, avec une voix française naturelle

Ce projet est un **fork** de [andreax79/ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) qui remplace le système TTS Google Translate du Nabaztag par une **synthèse vocale entièrement locale** via [Piper](https://github.com/OHF-Voice/piper1-gpl) (TTS neuronal, voix `fr_FR-siwis-medium`).

Le pipeline TTS ne se contente pas d'appeler Piper : il intègre plusieurs étapes de traitement pour obtenir un résultat à la hauteur des contraintes du lapin. Le texte à prononcer peut d'abord être converti en **phonèmes IPA** via [espeak-ng](https://github.com/espeak-ng/espeak-ng) (option `--phonemes`), ce qui améliore significativement la prononciation des mots rares, noms propres et sigles. Piper produit ensuite un flux WAV en 22kHz, qui est repris par [FFmpeg](https://ffmpeg.org/) pour un **post-traitement complet** : resampling à 16kHz (le format natif du Nabaztag), filtre passe-haut à 300Hz pour éliminer les basses que le petit haut-parleur ne peut de toute façon pas reproduire, amplification des aigus (+3dB) pour la clarté vocale, et un léger gain de volume (1.5x) pour compenser la faible puissance audio du lapin. Un en-tête WAV valide est reconstruit manuellement pour garantir la compatibilité avec le décodeur du firmware, qui n'accepte pas certains en-têtes produits par FFmpeg en mode streaming.

L'objectif est clair : **indépendance totale** vis-à-vis des API externes (Google Translate), une voix française naturelle et stable, un fonctionnement hors-ligne complet, et un temps de réponse inférieur à la seconde.

---

## Un firmware profondément retravaillé pour l'écosystème Home Assistant

Au-delà du pipeline TTS, `nab-piper` apporte de **nombreuses modifications au firmware** de `andreax79` pour assurer son bon fonctionnement en environnement serverless et son interfaçage avec Home Assistant. Ces modifications incluent :

- **Correction du bug NTP** : le calcul de l'heure présentait une dérive progressive (la soustraction de l'uptime au lieu du timestamp absolu) ; l'horloge du lapin est désormais fiable
- **4 flags de contrôle** (`autoclock`, `autohalftime`, `autosurprise`, `autotaichi`) : chaque automatisme peut être activé ou désactivé individuellement, via le firmware ou par HTTP
- **Endpoint `/autocontrol`** + champs dans `/status` JSON : l'état des flags est exposé dans l'API REST, et un endpoint dédié permet de les modifier à distance (`?c=1&h=0&s=1&t=1`)
- **Numéro de version dynamique** (`YYYYMMDDHHMM`) : injecté à chaque compilation, il force la mise à jour automatique du firmware par le lapin au démarrage
- **Configuration `locate.jsp`** : adaptée au mode serverless (pas de broadcast, pas de ping, découverte du serveur par URL HTTP)

Ces modifications sont détaillées dans le [CHANGELOG.md](CHANGELOG.md) qui liste l'intégralité des différences avec le fork d'origine, catégorie par catégorie.

---

## Un serveur Python modulaire avec deux pipelines TTS

Le projet s'articule autour d'un **serveur Python** (`piper_tts_stream.py`) qui expose un endpoint HTTP unique `GET /say?t=<texte>`. Lorsqu'il reçoit une requête du lapin, le serveur emprunte l'un des deux pipelines suivants selon le moteur configuré :

**Pipeline Piper** (par défaut) : le texte est d'abord converti en **phonèmes IPA** via `espeak-ng` (en mode `--phonemes`), ce qui donne à Piper des instructions phonétiques précises plutôt que du texte brut — le résultat est une diction nettement plus naturelle, en particulier pour les mots composés, les sigles et les noms propres. Piper, moteur C++ optimisé pour l'inférence ONNX, génère un flux WAV 22kHz en environ 100ms. Ce flux est immédiatement redirigé vers **FFmpeg** qui le resample à 16kHz, applique les filtres audio (passe-haut, aigus, volume), et produit un WAV 16-bit PCM mono, format natif du décodeur audio du Nabaztag. L'en-tête WAV est enfin reconstruit pour garantir une compatibilité parfaite avec le protocole HTTP simpliste du lapin (pas de `Transfer-Encoding: chunked`, pas de POST, attente d'une réponse complète).

**Pipeline Coqui** (alternatif) : plus lent que Piper (inférence en Python), mais offrant un choix de voix différent. Il peut être activé sans aucune modification du firmware — seul le serveur Python change de moteur.

Le choix de **Piper** comme moteur principal n'est pas anodin : sa latence très faible (~100ms par inférence, grâce à l'exécution C++ des modèles ONNX) le rend idéal pour un usage interactif où le lapin doit répondre rapidement. **FFmpeg**, de son côté, n'est pas un simple luxe : le décodeur audio du firmware Nabaztag attend du 16kHz mono, et le haut-parleur du lapin (petit tweeter 8Ω sans aucun grave) bénéficie énormément du filtrage passe-haut et de l'amplification des aigus — sans ces réglages, la voix sonnerait étouffée et à peine audible.

---

## Architecture

Le projet met en jeu **trois acteurs** communiquant par HTTP :

```
┌──────────────────┐     commandes      ┌───────────────────┐
│  Home Assistant  │───── REST ────────▶│   Nabaztag v2     │
│  (automatismes)  │                    │  (serveur HTTP    │
└──────────────────┘                    │   embarqué)       │
                                        └────────┬──────────┘
                                                 │
                    ┌────────────────────────────┼─────────────────┐
                    │  firmware, *.forth, MP3,   │                 │
                    │  animations, config        │  /say?t=...     │
                    │                            │  (synthèse)     │
                    ▼                            ▼                 ▼
          ┌──────────────────┐         ┌──────────────────┐
          │  Serveur web      │         │  Serveur TTS     │
          │  (port 80)        │         │  (port 6790)     │
          │                   │         │                  │
          │  vl/bc.jsp        │         │  piper_tts_stream │
          │  config/*.mp3     │         │  / Piper / Coqui │
          │  *.forth          │         └──────────────────┘
          │  animations.json  │
          └──────────────────┘
```

**Deux serveurs distincts tournent donc sur la machine hôte :**

- **Le serveur web statique** (port 80) : sert au lapin **tous ses fichiers de fonctionnement** — le firmware (`vl/bc.jsp`) qu'il télécharge à chaque démarrage, les fichiers de configuration Forth (`config.forth`, `hooks.forth`), les MP3 des annonces horaires et surprises (`config/clock/`, `config/clockall/`, `config/surprise/`), les données d'animations et les pages d'administration. C'est par cette adresse que le lapin se configure et trouve toutes ses ressources.

- **Le serveur Python TTS** (port 6790) : dédié à la **synthèse vocale**. Quand le lapin doit parler, il envoie une requête `GET /say?t=<texte>` à ce serveur qui génère le flux audio via Piper (ou Coqui) et le retourne directement sous forme de WAV 16kHz.

**Home Assistant** dialogue quant à lui directement avec le **serveur HTTP embarqué du lapin** (port 80 du lapin) via les endpoints `/forth`, `/autocontrol`, `/status` pour piloter les automatismes et lire les capteurs — sans passer par aucun intermédiaire.

---

## Installation

```bash
# 1. Cloner le dépôt
git clone https://github.com/jsapede/nabaztag-piper
cd nabaztag-piper/install

# 2. Copier et éditer la configuration
cp .env.example .env
nano .env
```

Variables essentielles à renseigner :

| Variable | Rôle | Exemple |
|----------|------|---------|
| `TTS_SERVER_IP` | IP du serveur où tourne Piper | `192.168.1.100` |
| `TTS_ENGINE` | Moteur TTS | `piper` (défaut) ou `coqui` |
| `PIPER_VOICE_PATH` | Voix Piper | `fr/fr_FR/siwis/medium` |
| `PIPER_USE_PHONEMES` | Activation des phonèmes espeak-ng | `true` |

```bash
# 3. Lancer l'installateur
./install.sh
```

Le script installe les dépendances (Piper, FFmpeg, espeak-ng), télécharge le modèle de voix, compile le firmware avec l'IP du serveur TTS, et configure les deux services systemd (`nabaztag-tts` pour la synthèse vocale, `nabaztag-webserver` pour le serveur de fichiers statiques).

#### 4. Pointer le lapin vers le serveur

Dans l'interface de connexion du lapin, configurer l'adresse du serveur web statique :

```
http://<IP_SERVEUR>:80/vl/
```

Le lapin télécharge son firmware (`bc.jsp`) à chaque démarrage et accède à toutes ses ressources (MP3, animations, configuration) depuis ce serveur.

---

## Home Assistant — Piloter le lapin par commandes REST

L'intégration repose sur un **package HA** (`homeassistant/nabaztag/`) qui expose tout le nécessaire pour contrôler le Nabaztag depuis Home Assistant. Le principe est simple : HA envoie des requêtes HTTP directement au **serveur HTTP embarqué du lapin** (port 80), sans intermédiaire.

Des **commandes REST paramétrables** (`rest_command`) permettent d'actionner toutes les fonctions du lapin : faire parler (`/say?t=...`), bouger les oreilles, changer la couleur du nez, afficher une animation météo, redémarrer, etc.

Le point central est l'endpoint **`/autocontrol`** qui permet d'activer ou désactiver à distance les fonctionnalités internes du firmware — les annonces horaires, les surprises, le taichi. Chacune est pilotée par un **switch HA** (`input_boolean`) qui met à jour le flag correspondant dans le firmware en temps réel, sans avoir à redémarrer le lapin.

Un **capteur REST** interroge régulièrement `/status` pour remonter l'état complet du lapin (sommeil, langue, configuration, flags actifs) et le rendre disponible dans HA pour les automatisations et les tableaux de bord.

### Scripts, automatisations et entités

Le package HA crée plusieurs familles d'entités pour interagir avec le lapin :

- **4 switches firmware** (`input_boolean`) : `nabaztag_firmware_clock`, `nabaztag_firmware_halftime`, `nabaztag_firmware_surprise`, `nabaztag_firmware_taichi` — chaque bascule est synchronisée en temps réel avec le firmware via l'endpoint `/autocontrol`
- **Entités de configuration** : l'adresse IP du lapin, la langue, le fuseau horaire, la position des oreilles, le message à dire
- **Capteur REST** : interroge `/status` toutes les 2 minutes et expose l'état complet (sommeil, flags, langue, version firmware)
- **Switches LEDs** : 4 `input_boolean` pour activer/désactiver les animations météo, trafic, pollution et nez

Des **scripts** automatisent les actions courantes : restaurer toutes les LEDs après une reconnexion, activer/désactiver une animation, et un script **Nabaztag Life** qui pioche aléatoirement parmi 10 actions (raconter une blague, annoncer la météo, donner l'heure, danser des oreilles, faire un bâillement, etc.).

Les **automatisations** assurent le lien automatique entre HA et le lapin :
- **Reconnexion** : au démarrage de HA ou au retour du lapin, envoie la configuration (`/setup`), restaure les LEDs et synchronise les flags firmware
- **Toggle LEDs** : quand l'utilisateur active/désactive une LED dans HA, le script approprié est déclenché
- **Nabaztag Life** : déclenche le script d'action aléatoire périodiquement pour rendre le lapin vivant

### Installation du package HA

Le package se trouve dans `homeassistant/nabaztag/`. Il suffit de copier ce dossier dans le répertoire `config/` de Home Assistant :

```
config/
├── configuration.yaml
└── nabaztag/
    ├── nabaztag_inputs.yaml       # Entités (text, select, number, boolean)
    ├── nabaztag_commands.yaml      # Commandes REST
    ├── nabaztag_sensors.yaml       # Capteur /status
    ├── nabaztag_scripts.yaml       # Scripts
    ├── nabaztag_automations.yaml   # Automatisations
    └── nabaztag_life.yaml          # Actions vivantes aléatoires
```

Puis ajouter dans `configuration.yaml` :

```yaml
homeassistant:
  packages: !include_dir_named nabaztag
```

Recharger la configuration HA (`ha_reload_core(target="all")`), puis renseigner l'adresse IP du lapin dans l'entité `input_text.nabaztag_ip_address`.

Les 6 fichiers du package sont automatiquement chargés et créent toutes les entités, commandes, scripts et automatisations décrits ci-dessus.

### Lovelace — Tableau de bord et guide des LEDs

Le dossier `homeassistant/lovelace/` contient trois fichiers YAML à importer comme cartes dans votre tableau de bord HA :

**`nabaztag_lovelace.yaml`** — le tableau de bord principal qui regroupe en un écran le contrôle des LEDs (météo, trafic, pollution, nez) et les switches firmware (horloge, demi-heure, surprise, taichi).

**`nabaztag_lovelace_config.yaml`** — une carte dédiée aux réglages avancés : langue, fuseau horaire, heures de réveil/coucher, fréquence taichi.

**`nabaztag_led_guide.yaml`** — un pense-bête visuel qui explique la signification des couleurs des LEDs (soleil, pluie, orage, trafic, pollution, nez).

Pour importer une carte : ouvrir le tableau de bord HA → cliquer sur l'icône crayon → **Ajouter carte** → passer en **éditeur YAML** → coller le contenu du fichier.

> **Dépendance telnet** : les sensors rapides (1s) et les switches firmware non-optimistes nécessitent `netcat-openbsd` sur la machine HA (`apt install netcat-openbsd`). Le sensor interroge le telnet du lapin (`nc -q 0 <IP> 23`) pour lire l'état réel des flags firmware et du sommeil, sans passer par HTTP.

Une documentation détaillée de l'intégration HA (entités, commandes REST, scripts, automatisations, guide des sons) est disponible dans [`homeassistant/docs/`](homeassistant/docs/INDEX.md).
