# Changelog - Nabaztag Serverless TTS

> Les versions détaillées sont disponibles dans les [GitHub Releases](https://github.com/jsapede/nabaztag-piper/releases).

## Comparatif : Original (`andreax79/ServerlessNabaztag`) vs Notre Repo

### 1. DNS (Domain Name System)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/protos/ntp_protos.mtl` | `var ntp_server = "pool.ntp.org";` | `var ntp_server = "216.239.35.12";` | ⚠️ **NTP server changé** de DNS pool vers IP fixe (fiable, évite les résolutions DNS hasardeuses) |

---

### 2. NTP (Network Time Protocol) — Correction de Bug

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/utils/time.mtl` (ligne 40) | `let offset * 60 + time -> offset in` | `let offset * 60 + (time - _ntp_receive_time) -> offset in` | ✅ **Bug NTP corrigé** : `time` était le uptime brut, pas le temps depuis la dernière synchro |
| `firmware/protos/time_protos.mtl` | Pas de variable `_ntp_receive_time` | `var _ntp_receive_time = 0;;` | ✅ **Nouvelle variable** pour tracker le moment de la dernière synchro NTP |

---

### 3. Commande `say` (Text-to-Speech)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/config.forth` | IP TTS codée en dur | `"http://192.168.0.35:6790/say?t=" constant TTS-SERVER$` (placeholder, remplacé par `install.sh`) | ✅ **IP TTS externalisée** dans une constante Forth |
| `vl/hooks.forth` | Google Translate TTS | Proxy TTS local via `TTS-SERVER$` | ✅ **Suppression Google Translate**, voix locale naturelle |
| `firmware/srv/http_server.mtl` | `forth_push_str f text;` | `forth_say_push f text;` | ✅ **Nouvelle fonction dédiée** pour le passage du texte au TTS |
| `firmware/forth/nabaztag.mtl` | Pas de `forth_say_push` | `fun forth_say_push f text=` | ✅ **Gestion d'encodage** pour le proxy TTS |

---

### 4. MP3 et Sons (Clock, Clockall, Surprise)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/hooks.forth` (clockall) | `12 random 1 +` (12 fichiers) | `11 random 1 +` (11 fichiers) | ✅ **Standardisation** : 11 fichiers génériques, supprimé préfixe `HG`/`hg` |
| `vl/hooks.forth` (clock) | Distribution inégale par heure | Toutes les heures 0-23 ont **exactement 6 fichiers** | ✅ **Uniforme** : heures creuses copiées depuis hour 10 |
| `vl/crontab.forth` (surprise) | `299 random 1 +` | `289 random 1 +` | ✅ **Standardisation** : 290 fichiers identiques pour toutes les langues |
| `_removed/` | N'existe pas | Sauvegarde des fichiers supprimés | ✅ **Non-destructif** : les fichiers en trop sont sauvegardés, pas supprimés définitivement |

---

### 5. Auto-Control Flags (activation/désactivation firmware)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/protos/forth_protos.mtl` | Pas de variables | `var _autoclock_enabled = 1;;` + 3 autres | ✅ **Variables MTL** pour stocker l'état des 4 flags |
| `firmware/forth/memory.mtl` | Pas de constantes mémoire | `FORTH_MEMORY_AUTOCLOCK_ENABLED` + 3 getters/setters | ✅ **Accès mémoire unifié** : `@`/`!` Forth standards |
| `firmware/forth/dictionary.mtl` | Pas de mots dédiés | `autoclock-enabled`, `autohalftime-enabled`, `autosurprise-enabled`, `autotaichi-enabled` | ✅ **Mots Forth** pour lecture/écriture par telnet |
| `firmware/srv/http_server.mtl` | `/status` sans les flags | `autoclock_enabled`, `autohalftime_enabled`, `autosurprise_enabled`, `autotaichi_enabled` dans `/status` | ✅ **API REST** : état des flags visible via HTTP |
| `firmware/srv/http_server.mtl` | Pas d'endpoint | `/autocontrol?c=1&h=0&s=1&t=1` | ✅ **Contrôle HTTP** : modifier les flags par requête HTTP |
| `firmware/forth/nabaztag.mtl` | Pas de fonction | Nouveau mot Forth `status-all` (lit 8 valeurs en un appel compilé, ~300ms) | ✅ **Lecture atomique** : sleep_state + 4 flags + 3 info services en une commande |
| `vl/hooks.forth` | Exécution inconditionnelle | `sleeping? invert autoclock-enabled @ and if` | ✅ **Respecte les flags** : horloge et demi-heure只在 réveil + flag actif |
| `vl/crontab.forth` | Exécution inconditionnelle | `sleeping? invert autosurprise-enabled @ and if` | ✅ **Respecte les flags** : surprise et taichi只在 réveil + flag actif |

---

### 6. Info Services (Météo, Trafic, Pollution) — Unifiés

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/srv/http_server.mtl` | `info.weather` dans sous-objet `info{}` | Ajout de `info_weather`, `info_traffic`, `info_pollution` en champs **plats** dans `/status` | ✅ **Accès uniforme** : mêmes champs plats que les 4 flags auto-control |
| `firmware/forth/nabaztag.mtl` | Mots `info-weather` etc. existent | Fonction `status-all` inclut la lecture des 3 services info | ✅ **Lecture cohérente** : tout est lu en un appel |

---

### 7. Configuration Serveur (`locate.jsp` et `config.forth`)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/locate.jsp` | ping/broadcast actifs | ping/broadcast désactivés, URL http ajoutée | ✅ **Mode SERVERLESS** : découverte du serveur via URL fixe |
| `vl/config.forth` | 3 lignes (username, password) | 13 lignes (commentaires, `TTS-SERVER$`, flags) | ✅ **Configuration enrichie** : tout est documenté et modifiable |

---

### 8. Numérotation du Firmware

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/main.mtl` | `$Rev: __DATE__$` | `$Rev: 202604300755$` (timestamp injecté) | ✅ **Versionnement automatique** à chaque compilation |
| `firmware/utils/url.mtl` | `const URL_BYTECODE_REVISION = "21029";` | Injecté dynamiquement | ✅ **Détection de mise à jour** par le rabbit |

---

### 9. Home Assistant — Intégration Complète

| Fichier / Fonction | Original (`andreax79`) | Notre Repo | Impact |
|--------------------|----------------------|----------|--------|
| `homeassistant/nabaztag/` | N'existe pas | 8 fichiers YAML + 2 scripts Python | ✅ **Intégration complète** dans Home Assistant |
| Capteur telnet | N'existe pas | `nab-read-status.py` + `status-all` → JSON en ~800ms | ✅ **Lecture fiable** par telnet, pas de problème de polling REST |
| Capteur REST (backup) | N'existe pas | REST `/status` conservé avec `scan_interval: 300` | ✅ **Redondance** : secours si telnet est indisponible |
| Binary sensors | N'existe pas | 8 binary_sensors template lisant le capteur telnet | ✅ **Visibilité UI** : état de chaque flag en temps réel |
| Automations firmware | N'existe pas | 4 automations pour les 4 flags (clock, halftime, surprise, taichi) | ✅ **Toggles** : input_boolean → telnet → update_entity |
| Automations LED | N'existe pas | Toggle weather/traffic/pollution/nose | ✅ **Contrôle LED** via input_boolean |
| `nab-telnet.py` | N'existe pas | Envoi de commande Forth par telnet avec `\r\n` (RFC Telnet) | ✅ **Communication fiable** avec le firmware |
| Mise à jour instantanée | N'existe pas | `homeassistant.update_entity` après chaque toggle | ✅ **Réactivité** : le capteur se rafraîchit immédiatement |

---

### 10. Taichi (Bug Typo Corrigé)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/crontab.forth` (ligne 30) | `taici-freq @` (typo) | `taichi-freq @` (corrigé) | ✅ **Bug corrigé** : le taichi fonctionne maintenant correctement |

---

### 11. Installateur et Outils

| Répertoire | Contenu | Impact |
|------------|---------|--------|
| `install/` | `install.sh` (interactif, 10 étapes, dry-run, désinstallation), `piper_tts_stream.py` (serveur TTS), `coqui_cli.py` (moteur alternatif) | ✅ **Installation complète** : détection de composants, reconstruction firmware, déploiement automatique |
