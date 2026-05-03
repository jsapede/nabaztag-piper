# Nabaztag Serverless — `nab-piper`

## A self-contained Nabaztag with natural French speech

This project is a **fork** of [andreax79/ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) that replaces the Nabaztag's Google Translate TTS with a **fully local speech synthesis** engine powered by [Piper](https://github.com/OHF-Voice/piper1-gpl) (neural TTS, voice `fr_FR-siwis-medium`).

The TTS pipeline does more than just calling Piper: it includes several processing stages to meet the rabbit's hardware constraints. The input text can first be converted to **IPA phonemes** via [espeak-ng](https://github.com/espeak-ng/espeak-ng) (`--phonemes` option), significantly improving pronunciation of rare words, proper nouns and acronyms. Piper then generates a 22kHz WAV stream, which is processed by [FFmpeg](https://ffmpeg.org/) for **full post-processing**: resampling to 16kHz (the Nabaztag's native format), 300Hz high-pass filter to remove inaudible bass, treble boost (+3dB) for speech clarity, and volume gain (1.5x) to compensate for the rabbit's small speaker. A valid WAV header is manually reconstructed to ensure compatibility with the firmware's audio decoder, which rejects certain headers produced by FFmpeg in streaming mode.

The goal is clear: **complete independence** from external APIs (Google Translate), natural and stable French speech, fully offline operation, and sub-second response time.

---

## A deeply reworked firmware for the Home Assistant ecosystem

Beyond the TTS pipeline, `nab-piper` brings **numerous firmware modifications** to `andreax79` to ensure smooth operation in a serverless environment and Home Assistant integration. These include:

- **NTP bug fix**: the time calculation had a progressive drift (uptime subtraction instead of absolute timestamp); the rabbit's clock is now reliable
- **4 control flags** (`autoclock`, `autohalftime`, `autosurprise`, `autotaichi`): each automation can be individually enabled or disabled, via firmware or HTTP
- **`/autocontrol` endpoint** + `/status` JSON fields: flag states exposed in the REST API, with a dedicated endpoint to modify them remotely (`?c=1&h=0&s=1&t=1`)
- **Dynamic version number** (`YYYYMMDDHHMM`): injected at each compilation, forcing automatic firmware update on rabbit boot
- **`locate.jsp` configuration**: adapted for serverless mode (no broadcast, no ping, HTTP URL server discovery)

These changes are detailed in the [CHANGELOG.en.md](CHANGELOG.en.md) which lists every difference from the original fork, category by category.

---

## A modular Python server with two TTS pipelines

The project is built around a **Python server** (`piper_tts_stream.py`) exposing a single HTTP endpoint `GET /say?t=<text>`. When the rabbit sends a request, the server uses one of two pipelines depending on the configured engine:

**Piper pipeline** (default): the text is first converted to **IPA phonemes** via `espeak-ng` (in `--phonemes` mode), giving Piper precise phonetic instructions instead of raw text — resulting in much more natural diction, especially for compound words, acronyms and proper nouns. Piper, a C++ engine optimized for ONNX inference, generates a 22kHz WAV stream in about 100ms. This stream is immediately piped to **FFmpeg** which resamples to 16kHz, applies audio filters (high-pass, treble, volume), and produces 16-bit PCM mono WAV — the native format of the Nabaztag's audio decoder. The WAV header is then manually reconstructed to guarantee full compatibility with the rabbit's simplistic HTTP client (no `Transfer-Encoding: chunked`, no POST, expects a complete response).

**Coqui pipeline** (alternative): slower than Piper (Python inference), but offering different voice options. It can be activated without any firmware modification — only the Python server changes engine.

The choice of **Piper** as the primary engine is deliberate: its very low latency (~100ms per inference, thanks to C++ ONNX execution) makes it ideal for interactive use where the rabbit must respond quickly. **FFmpeg**, on the other hand, is not a luxury: the Nabaztag firmware's audio decoder expects 16kHz mono, and the rabbit's speaker (a tiny 8Ω tweeter with no bass response) greatly benefits from high-pass filtering and treble boost — without these settings, the voice would sound muffled and barely audible.

---

## Architecture

The project involves **three actors** communicating via HTTP:

```
┌──────────────────┐    commands        ┌───────────────────┐
│  Home Assistant  │───── REST ────────▶│   Nabaztag v2     │
│  (automations)   │                    │  (embedded HTTP   │
└──────────────────┘                    │   server)         │
                                        └────────┬──────────┘
                                                 │
                    ┌────────────────────────────┼─────────────────┐
                    │  firmware, *.forth, MP3,   │                 │
                    │  animations, config        │  /say?t=...     │
                    │                            │  (synthesis)    │
                    ▼                            ▼                 ▼
          ┌──────────────────┐         ┌──────────────────┐
          │  Web server      │         │  TTS server      │
          │  (port 80)       │         │  (port 6790)     │
          │                  │         │                  │
          │  vl/bc.jsp       │         │  piper_tts_stream │
          │  config/*.mp3    │         │  / Piper / Coqui │
          │  *.forth         │         └──────────────────┘
          │  animations.json │
          └──────────────────┘
```

**Two separate servers run on the host machine:**

- **The static web server** (port 80): serves the rabbit **all its runtime files** — the firmware (`vl/bc.jsp`) downloaded on every boot, Forth configuration files (`config.forth`, `hooks.forth`), MP3 files for hourly chimes and surprises (`config/clock/`, `config/clockall/`, `config/surprise/`), animation data and admin pages. This is how the rabbit configures itself and finds all its resources.

- **The Python TTS server** (port 6790): dedicated to **speech synthesis**. When the rabbit needs to speak, it sends a `GET /say?t=<text>` request to this server, which generates the audio stream via Piper (or Coqui) and returns it directly as 16kHz WAV.

**Home Assistant** communicates directly with the **rabbit's embedded HTTP server** (port 80 on the rabbit) via `/forth`, `/autocontrol`, `/status` endpoints to control automations and read sensors — without any intermediary.

---

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/jsapede/nabaztag-piper
cd nabaztag-piper/install

# 2. Run the interactive installer
./install.sh
```

The script asks interactively for:
- The global installation directory
- The rabbit IP address
- The TTS server IP (where Piper runs)
- TTS and web server ports
- TTS engine (Piper or Coqui)

It automatically generates the `.env`, installs dependencies (Piper, FFmpeg, espeak-ng), downloads the voice model, compiles the firmware with the TTS IP, and configures both systemd services (`nabaztag-tts` for speech, `nabaztag-webserver` for static files).

#### 3. Point the rabbit to the server

In the rabbit's connection interface, set the static web server address:

```
http://<SERVER_IP>:80/vl/
```

The rabbit downloads its firmware (`bc.jsp`) on every boot and accesses all its resources (MP3, animations, configuration) from this server.

---

## Home Assistant — Controlling the rabbit via REST commands

The integration is based on an **HA package** (`homeassistant/nabaztag/`) providing everything needed to control the Nabaztag from Home Assistant. The principle is simple: HA sends HTTP requests directly to the **rabbit's embedded HTTP server** (port 80), without intermediaries.

**Parameterizable REST commands** (`rest_command`) can trigger all rabbit functions: speak (`/say?t=...`), move ears, change nose color, display weather animation, reboot, etc.

The central piece is the **`/autocontrol`** endpoint, which enables or disables firmware internal features — hourly chimes, surprises, taichi. Each feature is controlled by an **HA template switch** that updates the corresponding firmware flag in real time, without rebooting the rabbit.

A **telnet sensor** (`command_line`) queries the `status-all` Forth word via `nab-read-status.py` to retrieve the rabbit's full state (sleep, 4 firmware flags, weather, traffic, pollution) in ~800ms. A REST sensor keeps `/status` as backup every 300s.

### Scripts, automations and entities

The HA package creates several families of entities to interact with the rabbit:

- **4 non-optimistic firmware switches** (`switch.nabaztag_firmware_*`): clock, halftime, surprise, taichi — **template switches** reading the **actual firmware state** via telnet (1s). Toggling sends commands via telnet (`info-set`, `clear-info`).
- **3 non-optimistic LED switches** (`switch.nabaztag_led_*`): weather, traffic, pollution — real info service state via telnet, reading flat fields `info_weather`, `info_traffic`, `info_pollution`.
- **Telnet sensor** (`sensor.nabaztag_telnet_status`): queries `status-all` via `nab-read-status.py` for 8 values (sleep_state, 4 flags, 3 info services) in ~800ms.
- **Configuration entities**: rabbit IP, language, timezone, ear position, message
- **Backup REST sensor**: `/status` every 300s (language, version, timezone)
- **LED switches**: 4 `input_boolean` for enabling/disabling animations

### LED Animations

All animations are defined in `vl/config/animation/` and consolidated in `info_animations.json`:

| Service | Type | Levels | Tempo | Duration |
|---------|------|--------|-------|----------|
| 🌤️ **Weather** | Flare center↔sides | 6 (sun→storm) | 63 | ~5s |
| 🚗 **Traffic** | Snake left→right | 7 (free→extreme) | 33→133 | 2s→8s |
| 💨 **Pollution** | Bargraph + double blink | 11 (good→very bad) | 63 | ~5s |

Commands are sent via telnet using the Forth word `info-set ( val -- service )` added to the firmware, with `clear-info` to clear all.
- **Nabaztag Life**: triggers the random action script periodically to make the rabbit feel alive

### Installing the HA package

Copy the `homeassistant/nabaztag/` folder to your HA `config/` directory:

```
config/
├── configuration.yaml
└── nabaztag/
    ├── nabaztag_inputs.yaml       # Entities (text, select, number, boolean)
    ├── nabaztag_commands.yaml      # REST commands
    ├── nabaztag_sensors.yaml       # Sensors (telnet + REST backup)
    ├── nabaztag_scripts.yaml       # Scripts
    ├── nabaztag_automations.yaml   # Automations
    └── nabaztag_life.yaml          # Random life actions
```

Then add to `configuration.yaml`:

```yaml
homeassistant:
  packages: !include_dir_named nabaztag
```

Reload HA configuration (`ha_reload_core(target="all")`), then set the rabbit's IP address in the `input_text.nabaztag_ip_address` entity.

> **Note**: telnet sensors and `shell_command` use Python with `\r\n` (RFC Telnet) — no external binary (`nc`, `netcat`) is required.

### Lovelace — Dashboard and LED guide

The `homeassistant/lovelace/` folder contains three YAML files to import as cards in your HA dashboard:

**`nabaztag_lovelace.yaml`** — the main dashboard gathering LED controls (weather, traffic, pollution, nose) and firmware switches (clock, halftime, surprise, taichi) on one screen.

**`nabaztag_lovelace_config.yaml`** — a dedicated card for advanced settings: language, timezone, wake/sleep hours, taichi frequency.

**`nabaztag_led_guide.yaml`** — a visual reference explaining LED color meanings (sun, rain, storm, traffic, pollution, nose).

To import a card: open the HA dashboard → click the pencil icon → **Add card** → switch to **YAML editor** → paste the file contents.

> **Note**: the telnet sensor (`nab-read-status.py`) uses the `status-all` Forth word to read all 8 flags in one compiled call (~800ms). No external binary required — standard Python is sufficient.

Detailed HA integration documentation (entities, REST commands, scripts, automations, sound guide) is available in [`homeassistant/docs/`](homeassistant/docs/INDEX.md).

---

## License

This project is distributed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE).

Third-party dependencies (Piper, espeak-ng, FFmpeg, Coqui, voice models) have their own licenses — see [LICENSE-THIRD-PARTY.md](LICENSE-THIRD-PARTY.md).

This project is a fork of [ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) by `andreax79`.
