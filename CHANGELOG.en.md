# Changelog - Nabaztag Serverless TTS

## v0.2.0 — 2026-04-30

### New features
- **Interactive installer**: guided prompts (rabbit IP, TTS IP, ports, engine), auto `.env` generation
- **Component detection**: `which`/`test -f` to detect Piper, FFmpeg, espeak-ng, voice, services — reinstall menu
- **Firmware builds in tmpdir**: no repo pollution → `git pull` safe
- **HA package injection**: `homeassistant/nabaztag/` copied to `$GLOBAL_DIR` with rabbit IP pre-filled
- **nabaztag-check.sh**: service status, logs, bash alias `nabaztag`
- **Traffic snake animation**: 7-level chenillard (green→orange→red, variable speed)
- **Fixed telnet sensors**: `sleep_is_sleeping` → `sleeping?` (correct Forth words)
- **English docs**: `README.en.md` + `CHANGELOG.en.md`
- **GPL v3 license** + `LICENSE-THIRD-PARTY.md`

### Bug fixes
- Firmware build no longer modifies repo (tmpdir builds)
- Removed stray `local` keywords outside functions (bash error)
- Removed broken JSON manifest system (replaced by `which`/`test -f`)
- Restored accidentally deleted `run()` function
- GLOBAL_DIR conflict detection with clone directory
- Removed duplicate root `.env.example`

---

## Comparison: Original (`andreax79/ServerlessNabaztag`) vs Our Repo

### 1. DNS (Domain Name System)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/protos/ntp_protos.mtl` | `var ntp_server = "pool.ntp.org";` | `var ntp_server = "216.239.35.12";` | ⚠️ **NTP server changed** from DNS pool to fixed IP (reliable, avoids unreliable DNS resolution) |

---

### 2. NTP (Network Time Protocol) — Bug Fix

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/utils/time.mtl` (line 40) | `let offset * 60 + time -> offset in` | `let offset * 60 + (time - _ntp_receive_time) -> offset in` | ✅ **NTP bug fixed**: `time` was raw uptime, not time since last sync. Added `_ntp_receive_time` |
| `firmware/protos/time_protos.mtl` | No `_ntp_receive_time` variable | `var _ntp_receive_time = 0;;` (line 6) | ✅ **New variable** to track last NTP sync time |

---

### 3. `say` Command (Text-to-Speech)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/config.forth` | No `TTS-SERVER$` (hardcoded IP in `hooks.forth`) | `"http://192.168.0.35:6790/say?t=" constant TTS-SERVER$` (line 7, placeholder) | ✅ **Externalized TTS IP**: uses Forth constant, replaced by `sed` via `install.sh` |
| `vl/hooks.forth` (line 29) | `"/config/clockall/" :: language @ :: "/" :: 12 random 1 + :: ".mp3"` | `"/config/clockall/" :: language @ :: "/" :: 11 random 1 + :: ".mp3"` | ✅ **MP3 clockall standardized**: 11 files (`1.mp3`→`11.mp3`), generic (not hour-specific). Removed `HG`/`hg` prefix. Backed up in `_removed/` |
| `vl/hooks.forth` (line 23) | `"/config/clock/" :: language @ :: "/" :: get-hour :: "/" :: 6 random 1 + :: ".mp3"` | Unchanged | ✅ **Clock standardized**: all hours 0-23 now have exactly 6 MP3 files (`fr`, `es`, `uk`, `it`, `de`). Empty hours (de/0-9) copied from hour 10. Files >6 removed and saved to `_removed/` |
| `vl/crontab.forth` (line 8) | `"/config/surprise/" :: language @ :: "/" :: 299 random 1 + :: ".mp3"` | `"/config/surprise/" :: language @ :: "/" :: 289 random 1 + :: ".mp3"` | ✅ **Surprise standardized**: 290 files everywhere (`fr`, `es`, `uk`, `de`, `it`). Languages with <290 files were duplicated, >290 files removed and saved to `_removed/` |
| `vl/hooks.forth` (line 43) | `nil "http://translate.google.com/translate_tts?ie=UTF-8&..." :: language @ :: "&q=" :: r> :: str-join` | `nil TTS-SERVER$ :: r> :: str-join` | ✅ **Google Translate removed**: uses our TTS proxy (Piper/Coqui) via `TTS-SERVER$` |
| `firmware/srv/http_server.mtl` (line 253) | `forth_push_str f text;` | `forth_say_push f text;` | ✅ **New `forth_say_push` function** in `nabaztag.mtl` (better encoding handling for proxy) |
| `firmware/forth/nabaztag.mtl` | No `forth_say_push` function | `fun forth_say_push f text=` (line 148) | ✅ **Dedicated function** added to pass text to TTS engine |

---

### 4. Firmware Versioning

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/main.mtl` (line 35) | `const BYTECODE_REVISION_STR = "$Rev: __DATE__$";` | `const BYTECODE_REVISION_STR = "$Rev: XXX_REVISION_XXX$";` → injected: `"$Rev: 202604300755$"` | ✅ **Date+time**: forces LANA auto-update on every compilation |
| `firmware/utils/url.mtl` (line 2) | `const URL_BYTECODE_REVISION = "21029";` | `const URL_BYTECODE_REVISION = "XXX_REVISION_XXX";` → injected: `"202604300755"` | ✅ **Dynamic number**: detects firmware updates |
| `Makefile` (lines 37-39) | Compile `bootcode.bin` → copy to `vl/bc.jsp` | Same + `install.sh` injects timestamp | ✅ **Improved mechanism**: automatic versioning |

---

### 5. Auto-Control Flags (New)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/hooks.forth` (lines 22, 28) | No flag checks | `sleeping? invert autoclock-enabled @ and if` (added flag) | ✅ **4 flags added**: `autoclock`, `autohalftime`, `autosurprise`, `autotaichi` |
| `vl/crontab.forth` (lines 7, 22) | No flag checks | `sleeping? invert autosurprise-enabled @ and if` / `autotaichi-enabled @ and if` | ✅ **Granular control**: each feature can be individually toggled |
| `firmware/forth/memory.mtl` (lines 164-170) | No `_autoclock_enabled` variables | `var _autoclock_enabled = 0;;` (and 3 more) | ✅ **MTL variables** to store flag state in memory |
| `firmware/forth/dictionary.mtl` (lines 194-197) | No `autoclock-enabled` words | `[str:"autoclock-enabled" ] [ code:{[int:FORTH_MEMORY_AUTOLOCK_ENABLED]} ]` (and 3 more) | ✅ **Forth words** added to dictionary for modification via `!` |
| `firmware/srv/http_server.mtl` (lines 158-161, 420-443) | No `/autocontrol` endpoint | Added `http_get_autocontrol` and `autoclock_enabled` in `/status` | ✅ **REST API**: `/autocontrol?c=1&h=0&s=1&t=1` endpoint for HTTP configuration |

---

### 6. Taichi (Bug Fix — Typo)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/crontab.forth` (line 30) | `taici-freq @` (typo: `taici` instead of `taichi`) | `taichi-freq @` (fixed) | ✅ **Bug fixed**: `taici` → `taichi` in `crontab.forth` and `dictionary.mtl`, taichi now works correctly |

---

### 7. Server Configuration (`locate.jsp`)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/locate.jsp` | `# ping 192.168.1.1` / `# broad 192.168.1.1` | `# ping 0.0.0.0` / `# broad 0.0.0.0` (disabled) + `# http http://192.168.0.42` | ✅ **SERVERLESS mode**: ping/broadcast disabled, HTTP URL added for server discovery |

---

### 8. Configuration (`config.forth`)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/config.forth` | 3 lines (username, password) | 13 lines (comments, TTS-SERVER$, flags) | ✅ **Enriched config**: added `install.sh` comments, `TTS-SERVER$` constant, auto-control flags note |

---

### 9. New Files (New in Our Repo)

| Directory | Content | Impact |
|-----------|---------|--------|
| `install/` | `install.sh` (14.3K), `piper_tts_stream.py` (22.4K), `coqui_cli.py` (2.7K), `.env.example` (2.5K) | ✅ **Complete system**: unified installer (10 steps), dual-engine TTS proxy (Piper + Coqui), configuration |
| `homeassistant/` | `nabaztag_commands.yaml`, `nabaztag_sensors.yaml`, `nabaztag_automations.yaml`, etc. | ✅ **Home Assistant integration**: REST commands, sensors, LED automations, documentation |
| Root | `CHANGELOG.md`, `bootcode.bin` (94.9K), `.env` | ✅ **Documentation and compiled firmware**: release notes, ready-to-use binary |

---

### 10. HTTP Server (`http_server.mtl`)

| Item | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `/status` JSON (lines 147-169 vs 147-173) | No `autoclock_enabled` fields | Added `"autoclock_enabled": _autoclock_enabled,` (and 3 more) | ✅ **Full status**: API now returns all 4 auto-control flags |
| `/autocontrol` endpoint | Does not exist | `http_get_autocontrol` (lines 428-443) | ✅ **New API**: enables/disables features via HTTP (uses `forth_interpreter_ex` since MTL cannot write Forth variables) |
| `/setup` (lines 397-408 vs 401-415) | `config_set_taichi_freq` only | Added `http_arg_str args 'u'` → `config_set_server_url` (for SERVERLESS mode) | ✅ **Server URL** configurable via HTTP (for XMPP-free mode) |
