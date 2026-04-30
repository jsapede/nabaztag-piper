# Changelog - Nabaztag Serverless TTS

## Comparatif : Original (`andreax79/ServerlessNabaztag`) vs Notre Repo

### 1. DNS (Domain Name System)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/protos/ntp_protos.mtl` | `var ntp_server = "pool.ntp.org";` | `var ntp_server = "216.239.35.12";` | ⚠️ **NTP server changé** de DNS pool vers IP fixe (fiable, évite les résolutions DNS hasardeuses) |

---

### 2. NTP (Network Time Protocol) — Correction de Bug

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/utils/time.mtl` (ligne 40) | `let offset * 60 + time -> offset in` | `let offset * 60 + (time - _ntp_receive_time) -> offset in` | ✅ **Bug NTP corrigé** : `time` était le uptime brut, pas le temps depuis la dernière synchro. Ajout de `_ntp_receive_time` |
| `firmware/protos/time_protos.mtl` | Pas de variable `_ntp_receive_time` | `var _ntp_receive_time = 0;;` (ligne 6) | ✅ **Nouvelle variable** pour tracker le moment de la dernière synchro NTP |

---

### 3. Commande `say` (Text-to-Speech)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/config.forth` | Pas de `TTS-SERVER$` (IP codée en dur dans `hooks.forth`) | `"http://192.168.0.35:6790/say?t=" constant TTS-SERVER$` (ligne 7, placeholder) | ✅ **IP TTS externalisée** : utilise une constante Forth, remplacée par `sed` via `install.sh` |
| `vl/hooks.forth` (ligne 29) | `"/config/clockall/" :: language @ :: "/" :: 12 random 1 + :: ".mp3"` | `"/config/clockall/" :: language @ :: "/" :: 11 random 1 + :: ".mp3"` | ✅ **Standardisation MP3 clockall** : 11 fichiers (`1.mp3`→`11.mp3`), génériques (pas liés à l'heure). Suppression préfixe `HG`/`hg`. Sauvegarde dans `_removed/` |
| `vl/hooks.forth` (ligne 23) | `"/config/clock/" :: language @ :: "/" :: get-hour :: "/" :: 6 random 1 + :: ".mp3"` | Inchangé | ✅ **Standardisation clock** : toutes les heures 0-23 ont exactement 6 fichiers MP3 (`fr`, `es`, `uk`, `it`, `de`). Les heures vides (de/0-9) ont été copiées depuis hour 10. Fichiers >6 supprimés et sauvegardés dans `_removed/` |
| `vl/crontab.forth` (ligne 8) | `"/config/surprise/" :: language @ :: "/" :: 299 random 1 + :: ".mp3"` | `"/config/surprise/" :: language @ :: "/" :: 289 random 1 + :: ".mp3"` | ✅ **Standardisation surprise** : 290 fichiers partout (`fr`, `es`, `uk`, `de`, `it`). Certaines langues avaient <290 fichiers (duplication), d'autres >290 (suppression sauvegardée dans `_removed/`) |
| `vl/config/weather/` | Fichiers `-*.mp3` (noms invalides, ex: `-2.mp3`) | Renommés `neg*.mp3` (ex: `neg2.mp3`) | ✅ **Standardisation weather** : fichiers à nom invalide (`-*.mp3`) renommés `neg*.mp3`. Récupérés depuis le repo original. Contient des annonces de températures négatives ("Moins deux", "Moins quatre") et diverses (Bonjour, Moïse, etc.) |
| `vl/hooks.forth` (ligne 43) | `nil "http://translate.google.com/translate_tts?ie=UTF-8&..." :: language @ :: "&q=" :: r> :: str-join` | `nil TTS-SERVER$ :: r> :: str-join` | ✅ **Suppression Google Translate** : utilise notre proxy TTS (Piper/Coqui) via `TTS-SERVER$` |
| `firmware/srv/http_server.mtl` (ligne 253) | `forth_push_str f text;` | `forth_say_push f text;` | ✅ **Nouvelle fonction `forth_say_push`** dans `nabaztag.mtl` (gère mieux l'encodage pour le proxy) |
| `firmware/forth/nabaztag.mtl` | Pas de fonction `forth_say_push` | `fun forth_say_push f text=` (ligne 148) | ✅ **Ajout de la fonction dédiée** pour passer le texte au moteur TTS |

---

### 4. Numérotation du Firmware

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `firmware/main.mtl` (ligne 35) | `const BYTECODE_REVISION_STR = "$Rev: __DATE__$";` | `const BYTECODE_REVISION_STR = "$Rev: XXX_REVISION_XXX$";` → injecté: `"$Rev: 202604300755$"` | ✅ **Date+heure** : force LANA auto-update à chaque compilation |
| `firmware/utils/url.mtl` (ligne 2) | `const URL_BYTECODE_REVISION = "21029";` | `const URL_BYTECODE_REVISION = "XXX_REVISION_XXX";` → injecté: `"202604300755"` | ✅ **Numéro dynamique** : détecte les mises à jour firmware |
| `Makefile` (ligne 37-39) | Compile `bootcode.bin` → copie vers `vl/bc.jsp` | Identique + `install.sh` injecte le timestamp | ✅ **Mécanisme amélioré** : versioning automatique |

---

### 5. Auto-Control Flags (Nouveau)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/hooks.forth` (lignes 22, 28) | Pas de vérification des flags | `sleeping? invert autoclock-enabled @ and if` (ajout du flag) | ✅ **4 flags ajoutés** : `autoclock`, `autohalftime`, `autosurprise`, `autotaichi` |
| `vl/crontab.forth` (lignes 7, 22) | Pas de vérification | `sleeping? invert autosurprise-enabled @ and if` / `autotaichi-enabled @ and if` | ✅ **Contrôle granulaire** : chaque fonctionnalité peut être activée/désactivée individuellement |
| `firmware/forth/memory.mtl` (lignes 164-170) | Pas de variables `_autoclock_enabled`, etc. | `var _autoclock_enabled = 0;;` (et 3 autres) | ✅ **Variables MTL** pour stocker l'état des flags en mémoire |
| `firmware/forth/dictionary.mtl` (lignes 194-197) | Pas de mots `autoclock-enabled`, etc. | `[str:"autoclock-enabled" ] [ code:{[int:FORTH_MEMORY_AUTOLOCK_ENABLED]} ]` (et 3 autres) | ✅ **Mots Forth** ajoutés au dictionnaire pour modification via `!` |
| `firmware/srv/http_server.mtl` (lignes 158-161, 420-443) | Pas d'endpoint `/autocontrol` | Ajout de `http_get_autocontrol` et de `autoclock_enabled` dans `/status` | ✅ **API REST** : endpoint `/autocontrol?c=1&h=0&s=1&t=1` pour configurer via HTTP |

---

### 6. Taichi (Bug Typo Corrigé)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/crontab.forth` (ligne 30) | `taici-freq @` (typo : `taici` au lieu de `taichi`) | `taichi-freq @` (corrigé) | ✅ **Bug corrigé** : `taici` → `taichi` dans `crontab.forth` et `dictionary.mtl`, le taichi fonctionne maintenant correctement |

---

### 7. Configuration Serveur (`locate.jsp`)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/locate.jsp` | `# ping 192.168.1.1` / `# broad 192.168.1.1` | `# ping 0.0.0.0` / `# broad 0.0.0.0` (désactivé) + `# http http://192.168.0.42` | ✅ **Mode SERVERLESS** : ping/broadcast désactivés, URL HTTP ajoutée pour la découverte du serveur |

---

### 8. Configuration (`config.forth`)

| Fichier | Original (`andreax79`) | Notre Repo | Impact |
|---------|----------------------|-------------|--------|
| `vl/config.forth` | 3 lignes (username, password) | 13 lignes (commentaires, TTS-SERVER$, flags) | ✅ **Configuration enrichie** : ajout des commentaires `install.sh`, constante `TTS-SERVER$`, note sur les flags auto-control |

---

### 9. Fichiers Ajoutés (Nouveau dans Notre Repo)

| Répertoire | Contenu | Impact |
|------------|---------|--------|
| `install/` | `install.sh` (14.3K), `piper_tts_stream.py` (22.4K), `coqui_cli.py` (2.7K), `.env.example` (2.5K) | ✅ **Système complet** : installateur unifié (10 étapes), proxy TTS dual-engine (Piper + Coqui), configuration |
| `homeassistant/` | `nabaztag_commands.yaml`, `nabaztag_sensors.yaml`, `nabaztag_automations.yaml`, etc. | ✅ **Intégration Home Assistant** : 2 commandes REST, 1 capteur, automatisations LED, documentation |
| Racine | `CHANGELOG.md`, `bootcode.bin` (94.9K), `.env` | ✅ **Documentation et firmware compilé** : notes de version, binaire prêt à l'emploi |

---

### 10. HTTP Server (`http_server.mtl`)

| Élément | Original (`andreax79`) | Notre Repo | Impact |
|----------|----------------------|-------------|--------|
| `/status` JSON (lignes 147-169 vs 147-173) | Pas de champs `autoclock_enabled`, etc. | Ajout de `"autoclock_enabled": _autoclock_enabled,` (et 3 autres) | ✅ **Status complet** : l'API renvoie maintenant l'état des 4 flags auto-control |
| `/autocontrol` endpoint | N'existe pas | `http_get_autocontrol` (lignes 428-443) | ✅ **Nouvelle API** : permet d'activer/désactiver les fonctionnalités via HTTP (utilise `forth_interpreter_ex` car MTL ne peut pas écrire de variables Forth) |
| `/setup` (ligne 397-408 vs 401-415) | `config_set_taichi_freq` seulement | Ajout de `http_arg_str args 'u'` → `config_set_server_url` (pour mode SERVERLESS) | ✅ **URL du serveur** configurable via HTTP (pour mode sans XMPP) |
