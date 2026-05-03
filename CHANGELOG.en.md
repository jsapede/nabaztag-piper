# Changelog - Nabaztag Serverless TTS

> Detailed versions are available in [GitHub Releases](https://github.com/jsapede/nabaztag-piper/releases).

## Comparison: Original (`andreax79/ServerlessNabaztag`) vs Our Repo

### 1. DNS (Domain Name System)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/protos/ntp_protos.mtl` | `var ntp_server = "pool.ntp.org";` | `var ntp_server = "216.239.35.12";` | ⚠️ **NTP server changed** from DNS pool to fixed IP (reliable, avoids DNS resolution issues) |

---

### 2. NTP (Network Time Protocol) — Bug Fix

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/utils/time.mtl` (line 40) | `let offset * 60 + time -> offset in` | `let offset * 60 + (time - _ntp_receive_time) -> offset in` | ✅ **NTP bug fixed**: `time` was raw uptime, not time since last sync |
| `firmware/protos/time_protos.mtl` | No `_ntp_receive_time` variable | `var _ntp_receive_time = 0;;` | ✅ **New variable** to track last NTP sync time |

---

### 3. `say` Command (Text-to-Speech)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/config.forth` | Hardcoded TTS IP | `"http://192.168.0.35:6790/say?t=" constant TTS-SERVER$` (placeholder, replaced by `install.sh`) | ✅ **Externalized TTS IP** as a Forth constant |
| `vl/hooks.forth` | Google Translate TTS | Local TTS proxy via `TTS-SERVER$` | ✅ **Google Translate removed**, replaced by local neural voice |
| `firmware/srv/http_server.mtl` | `forth_push_str f text;` | `forth_say_push f text;` | ✅ **New dedicated function** for passing text to TTS engine |
| `firmware/forth/nabaztag.mtl` | No `forth_say_push` | `fun forth_say_push f text=` | ✅ **Encoding support** for the TTS proxy |

---

### 4. MP3 Files (Clock, Clockall, Surprise)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/hooks.forth` (clockall) | `12 random 1 +` (12 files) | `11 random 1 +` (11 files) | ✅ **Standardized**: 11 generic files per language, removed `HG`/`hg` prefix |
| `vl/hooks.forth` (clock) | Uneven distribution per hour | All hours 0-23 have **exactly 6 files** | ✅ **Uniform**: empty hours copied from hour 10, excess backed up |
| `vl/crontab.forth` (surprise) | `299 random 1 +` | `289 random 1 +` | ✅ **Standardized**: 290 identical files for all languages |
| `_removed/` | Does not exist | Backup of removed files | ✅ **Non-destructive**: excess files are backed up, not deleted |

---

### 5. Auto-Control Flags (firmware enable/disable)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/protos/forth_protos.mtl` | No variables | `var _autoclock_enabled = 1;;` + 3 more | ✅ **MTL variables** to store all 4 flag states |
| `firmware/forth/memory.mtl` | No memory constants | `FORTH_MEMORY_AUTOCLOCK_ENABLED` + 3 getters/setters | ✅ **Unified memory access**: standard Forth `@`/`!` |
| `firmware/forth/dictionary.mtl` | No dedicated words | `autoclock-enabled`, `autohalftime-enabled`, `autosurprise-enabled`, `autotaichi-enabled` | ✅ **Forth words** for telnet read/write |
| `firmware/srv/http_server.mtl` | `/status` without flags | `autoclock_enabled`, `autohalftime_enabled`, `autosurprise_enabled`, `autotaichi_enabled` in `/status` | ✅ **REST API**: flag state visible via HTTP |
| `firmware/srv/http_server.mtl` | No endpoint | `/autocontrol?c=1&h=0&s=1&t=1` | ✅ **HTTP control**: modify flags via HTTP request |
| `firmware/forth/nabaztag.mtl` | No function | New Forth word `status-all` (reads 8 values in one compiled call, ~300ms) | ✅ **Atomic read**: sleep_state + 4 flags + 3 info services in one command |
| `vl/hooks.forth` | Unconditional execution | `sleeping? invert autoclock-enabled @ and if` | ✅ **Flag-aware**: clock and halftime only when awake + flag active |
| `vl/crontab.forth` | Unconditional execution | `sleeping? invert autosurprise-enabled @ and if` | ✅ **Flag-aware**: surprise and taichi only when awake + flag active |

---

### 6. Info Services (Weather, Traffic, Pollution) — Unified

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/srv/http_server.mtl` | `info.weather` in sub-object `info{}` | Added `info_weather`, `info_traffic`, `info_pollution` as **flat** fields in `/status` | ✅ **Uniform access**: same flat fields as the 4 auto-control flags |
| `firmware/forth/nabaztag.mtl` | `info-weather` etc. exist | `status-all` includes reading all 3 info services | ✅ **Consistent read**: everything read in one call |

---

### 7. Server Configuration (`locate.jsp` and `config.forth`)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/locate.jsp` | ping/broadcast active | ping/broadcast disabled, http URL added | ✅ **SERVERLESS mode**: server discovery via fixed URL |
| `vl/config.forth` | 3 lines (username, password) | 13 lines (comments, `TTS-SERVER$`, flags) | ✅ **Enriched configuration**: everything documented and editable |

---

### 8. Firmware Versioning

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `firmware/main.mtl` | `$Rev: __DATE__$` | `$Rev: 202604300755$` (injected timestamp) | ✅ **Automatic versioning** on every build |
| `firmware/utils/url.mtl` | `const URL_BYTECODE_REVISION = "21029";` | Dynamically injected | ✅ **Update detection** by the rabbit |

---

### 9. Home Assistant — Full Integration

| File / Feature | Original (`andreax79`) | Our Repo | Impact |
|---------------|----------------------|----------|--------|
| `homeassistant/nabaztag/` | Does not exist | 8 YAML files + 2 Python scripts | ✅ **Complete** Home Assistant integration |
| Telnet sensor | Does not exist | `nab-read-status.py` + `status-all` → JSON in ~800ms | ✅ **Reliable read** via telnet, no REST polling issues |
| REST sensor (backup) | Does not exist | REST `/status` kept with `scan_interval: 300` | ✅ **Redundancy**: fallback if telnet unavailable |
| Binary sensors | Does not exist | 8 template binary_sensors reading the telnet sensor | ✅ **UI visibility**: real-time state of every flag |
| Firmware automations | Does not exist | 4 automations for the 4 flags (clock, halftime, surprise, taichi) | ✅ **Toggles**: input_boolean → telnet → update_entity |
| LED automations | Does not exist | Toggle weather/traffic/pollution/nose | ✅ **LED control** via input_boolean |
| `nab-telnet.py` | Does not exist | Sends Forth commands via telnet with `\r\n` (RFC Telnet) | ✅ **Reliable communication** with the firmware |
| Instant refresh | Does not exist | `homeassistant.update_entity` after every toggle | ✅ **Responsiveness**: sensor refreshes immediately |

---

### 10. Taichi (Bug Typo Fixed)

| File | Original (`andreax79`) | Our Repo | Impact |
|------|----------------------|----------|--------|
| `vl/crontab.forth` (line 30) | `taici-freq @` (typo) | `taichi-freq @` (fixed) | ✅ **Bug fixed**: taichi now works correctly |

---

### 11. Installer and Tools

| Directory | Content | Impact |
|-----------|---------|--------|
| `install/` | `install.sh` (interactive, 10 steps, dry-run, uninstall), `piper_tts_stream.py` (TTS server), `coqui_cli.py` (alternative engine) | ✅ **Complete installation**: component detection, firmware rebuild, automatic deployment |
