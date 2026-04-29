#!/usr/bin/env python3
"""
Piper TTS Stream Proxy for Nabaztag v2

This proxy receives TTS requests from the Nabaztag v2 firmware and generates
audio using the local Piper TTS engine with FFmpeg for audio processing.

================================================================================
HOW THE SAY COMMAND WORKS (Nabaztag v2 -> TTS Proxy)
================================================================================

1. FIRMWARE TRIGGER:
   When the Nabaztag needs to speak, the Forth firmware calls the `say` word.
   Located in: /opt/New_Serverless_v3/vl/hooks.forth (lines 40-45)

   : say ( text -- )
     sleeping? invert if
     url-encode >r
     nil "http://192.168.0.42:6790/say?t=" :: r> :: str-join
     play-url
     then ;

2. HTTP REQUEST:
   The firmware makes a simple HTTP GET request:
   GET http://192.168.0.42:6790/say?t=<url-encoded-text>

3. PROXY PROCESSING:
   This proxy receives the request and:
   - Parses the "t" parameter (text to speak)
   - Optionally accepts "voice" parameter (defaults to PIPER_DEFAULT_VOICE)
   - Launches Piper locally with the text
   - Generates a valid RIFF/WAV audio stream via FFmpeg:
     * Resamples to 16kHz (Nabaztag compatible)
     * Applies high-pass filter (removes low rumble)
     * Applies treble boost (speech clarity)
     * Applies volume boost (for small speaker)
   - Streams it back WITHOUT Transfer-Encoding: chunked

4. NABAZTAG PLAYBACK:
   The firmware's audio decoder (audiolib.mtl) receives the WAV stream and
   plays it through the speaker.

================================================================================
TECHNICAL CONSTRAINTS FROM NABAZTAG HARDWARE
================================================================================

- WAV_BUFFER_STARTSIZE=64000 (initial buffer in firmware/audio/audiolib.mtl)
- Expected: 16kHz mono 16-bit PCM WAV
- HTTP/1.0 client - NO Transfer-Encoding: chunked support
- Uses play-url (simple HTTP GET, not POST)
- Simple HTTP client that expects a complete WAV response

================================================================================
AUDIO PIPELINE
================================================================================

Text -> Piper (22kHz/44kHz WAV) -> FFmpeg (16kHz mono + filters) -> Nabaztag

FFmpeg filters applied:
- highpass=f=300: Remove low rumble (small speaker can't reproduce bass)
- treble=g=3: Boost treble for speech intelligibility
- volume=1.5: Increase volume for better hearing

Output format: 16kHz mono 16-bit PCM WAV

================================================================================
ENVIRONMENT VARIABLES
================================================================================

  PIPER_BINARY          Full path to piper executable
                        Default: /root/.local/bin/piper

  PIPER_VOICES_FOLDER   Directory containing voice model files (.onnx)
                        Default: /opt/configs/piper (server)

  PIPER_DEFAULT_VOICE   Voice name (without .onnx extension)
                        Default: fr_FR-siwis-medium

  PIPER_SPEAKER         Speaker index (0, 1, 2... for multi-speaker models)
                        Default: 0

  PIPER_LENGTH_SCALE    Speech speed (0.5-2.0, higher = slower)
                        Default: 1.5

  PIPER_NOISE_SCALE     Generator noise (0.0-1.0, Piper default: 0.667)
                        Default: 0.667

  PIPER_NOISE_W_SCALE   Phoneme width noise (0.0-1.0, Piper default: 0.8)
                        Default: 0.333

  PIPER_VOLUME          Volume multiplier (Piper default: 1.0)
                        Default: 1

  PIPER_SENTENCE_SILENCE Seconds of silence after each sentence
                        Default: 0.2

  FFMPEG_BINARY         Full path to FFmpeg executable
                        Default: /usr/bin/ffmpeg

  PIPER_USE_FFMPEG      Enable FFmpeg transcoding (resampling + filters)
                        Default: true

  PIPER_TARGET_SAMPLE_RATE Target sample rate for output
                          Default: 16000

  FFMPEG_VOLUME         Volume boost via FFmpeg filter
                        Default: 1.5

  FFMPEG_HIGH_PASS      High-pass filter frequency (Hz)
                        Removes low rumble for small speakers
                        Default: 300

  FFMPEG_TREBLE         Treble boost (dB) for speech clarity
                        Default: 3

================================================================================
PIPER PARAMETERS EXPLAINED
================================================================================

-m, --model            Voice model name (e.g., fr_FR-siwis-medium)
                       Piper looks for {model}.onnx in --data-dir

--data-dir             Directory containing voice model files

-s, --speaker          Speaker index (0 = first speaker)
                       Use for multi-speaker models (e.g., mls, english_large)
                       siwis and tom have only 1 speaker (0)

--length-scale         Phoneme length multiplier
                       1.0 = normal speed, 1.5 = slower (better for Nabaztag)

--noise-scale          Generator noise (affects breathiness)
                       0.667 is Piper's default

--noise-w-scale         Phoneme width noise (affects articulation)
                       Lower values = clearer speech

--volume               Output volume multiplier (Piper's internal)
                       Default: 1 (handled by FFmpeg instead)

--sentence-silence     Seconds of silence between sentences
                       0.2 = 200ms silence

--output-file -        Write WAV to stdout (for streaming)
                       IMPORTANT: Do NOT use --output_raw (no WAV header!)

================================================================================
FFMPEG FILTERS EXPLAINED
================================================================================

highpass=f=300        High-pass filter at 300Hz
                       Removes low frequency rumble that small speakers
                       cannot reproduce. Improves clarity for speech.

treble=g=3             Treble boost of 3dB at high frequencies
                       Enhances speech intelligibility and presence.

volume=1.5             Volume multiplier
                       Boosts output volume for the Nabaztag speaker.

-ar 16000              Sample rate
                       Resamples to 16kHz (Nabaztag compatible)

-ac 1                  Channels
                       Converts to mono

-acodec pcm_s16le      Audio codec
                       16-bit signed little-endian PCM

-f wav                 Format
                       Forces WAV input/output for pipe streaming

================================================================================
"""

import argparse
import os
import socket
import struct
import subprocess
import time
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
import logging

# ==============================================================================
# CONFIGURATION (fallback defaults)
# ==============================================================================

DEFAULT_PIPER_BINARY = "/root/.local/bin/piper"
DEFAULT_VOICES_FOLDER = "/opt/configs/piper"
DEFAULT_VOICE = "fr_FR-siwis-medium"
DEFAULT_SPEAKER = "0"
DEFAULT_LENGTH_SCALE = "1.5"
DEFAULT_NOISE_SCALE = "0.667"
DEFAULT_NOISE_W_SCALE = "0.333"
DEFAULT_VOLUME = "1"
DEFAULT_SENTENCE_SILENCE = "0.2"

# Phoneme preprocessing configuration
DEFAULT_ESPEAK_BINARY = "/usr/bin/espeak-ng"
DEFAULT_USE_PHONEMES = False
DEFAULT_ESPEAK_VOICE = "fr"

# FFmpeg configuration
DEFAULT_FFMPEG_BINARY = "/usr/bin/ffmpeg"
DEFAULT_USE_FFMPEG = True
DEFAULT_TARGET_SAMPLE_RATE = 16000
DEFAULT_FFMPEG_VOLUME = "1.5"
DEFAULT_FFMPEG_HIGH_PASS = "300"
DEFAULT_FFMPEG_TREBLE = "3"
DEFAULT_FFMPEG_LOUDNORM = False
DEFAULT_FFMPEG_EXCITER = "0"
DEFAULT_FFMPEG_DEESSER = "0"

# Load from environment (allows override on server)
PIPER_BINARY = os.environ.get("PIPER_BINARY", DEFAULT_PIPER_BINARY)
VOICES_FOLDER = os.environ.get("PIPER_VOICES_FOLDER", DEFAULT_VOICES_FOLDER)
VOICE = os.environ.get("PIPER_DEFAULT_VOICE", DEFAULT_VOICE)
SPEAKER = os.environ.get("PIPER_SPEAKER", DEFAULT_SPEAKER)
LENGTH_SCALE = os.environ.get("PIPER_LENGTH_SCALE", DEFAULT_LENGTH_SCALE)
NOISE_SCALE = os.environ.get("PIPER_NOISE_SCALE", DEFAULT_NOISE_SCALE)
NOISE_W_SCALE = os.environ.get("PIPER_NOISE_W_SCALE", DEFAULT_NOISE_W_SCALE)
VOLUME = os.environ.get("PIPER_VOLUME", DEFAULT_VOLUME)
SENTENCE_SILENCE = os.environ.get("PIPER_SENTENCE_SILENCE", DEFAULT_SENTENCE_SILENCE)

# Phoneme settings
ESPEAK_BINARY = os.environ.get("ESPEAK_BINARY", DEFAULT_ESPEAK_BINARY)
USE_PHONEMES = os.environ.get("PIPER_USE_PHONEMES", "false").lower() == "true"
ESPEAK_VOICE = os.environ.get("ESPEAK_VOICE", DEFAULT_ESPEAK_VOICE)

# FFmpeg settings
FFMPEG_BINARY = os.environ.get("FFMPEG_BINARY", DEFAULT_FFMPEG_BINARY)
USE_FFMPEG = os.environ.get("PIPER_USE_FFMPEG", "true").lower() == "true"
USE_FFMPEG_FILTERS = True  # Can be disabled via --no-filters flag
TARGET_SAMPLE_RATE = int(
    os.environ.get("PIPER_TARGET_SAMPLE_RATE", DEFAULT_TARGET_SAMPLE_RATE)
)
FFMPEG_VOLUME = os.environ.get("FFMPEG_VOLUME", DEFAULT_FFMPEG_VOLUME)
FFMPEG_HIGH_PASS = os.environ.get("FFMPEG_HIGH_PASS", DEFAULT_FFMPEG_HIGH_PASS)
FFMPEG_TREBLE = os.environ.get("FFMPEG_TREBLE", DEFAULT_FFMPEG_TREBLE)
FFMPEG_LOUDNORM = os.environ.get("FFMPEG_LOUDNORM", "false").lower() == "true"
FFMPEG_EXCITER = os.environ.get("FFMPEG_EXCITER", DEFAULT_FFMPEG_EXCITER)
FFMPEG_DEESSER = os.environ.get("FFMPEG_DEESSER", DEFAULT_FFMPEG_DEESSER)

# Configure logger
logging.basicConfig(
    level=logging.INFO, format="[TTS-Proxy] %(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def create_valid_wav_header(data_size, sample_rate=16000):
    """
    Create a strict WAV header compatible with Nabaztag.

    This function creates a proper RIFF/WAV header with correct sizes,
    unlike FFmpeg which outputs streaming WAV with unknown sizes (ffff ffff).

    Format: mono 16-bit PCM at specified sample rate

    Header layout (44 bytes):
    - RIFF header: 12 bytes
    - fmt chunk: 24 bytes
    - data chunk: 8 bytes
    """
    header = bytearray(44)

    # RIFF header
    header[0:4] = b"RIFF"
    header[4:8] = struct.pack("<I", 36 + data_size)
    header[8:12] = b"WAVE"

    # fmt chunk (24 bytes total)
    header[12:16] = b"fmt "
    header[16:20] = struct.pack("<I", 16)  # fmt chunk size
    header[20:22] = struct.pack("<H", 1)  # Audio format: 1 = PCM
    header[22:24] = struct.pack("<H", 1)  # Channels: 1 = mono
    header[24:28] = struct.pack("<I", sample_rate)  # Sample rate
    header[28:32] = struct.pack("<I", sample_rate * 2)  # Byte rate
    header[32:34] = struct.pack("<H", 2)  # Block align
    header[34:36] = struct.pack("<H", 16)  # Bits per sample
    # Note: 36 - 20 = 16 bytes written, but fmt chunk is 24 bytes
    # So we need 8 more bytes (padding) but they get overwritten by data chunk

    # data chunk (overwrites the padding area)
    header[36:40] = b"data"
    header[40:44] = struct.pack("<I", data_size)

    return bytes(header)


def text_to_phonemes(text):
    """
    Convert text to IPA phonemes using espeak-ng.

    Returns phonemes wrapped in [[phonemes]] format for Piper.
    Piper interprets [[phonemes]] as raw espeak-ng phonemes.
    """
    try:
        cmd = [ESPEAK_BINARY, "-v", ESPEAK_VOICE, "--ipa=3", "-q", text]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if result.returncode == 0 and result.stdout.strip():
            phonemes = result.stdout.strip()
            return f"[[{phonemes}]]"
        else:
            logger.warning(f"espeak-ng failed or empty: {result.stderr}")
            return text
    except Exception as e:
        logger.error(f"Phoneme conversion error: {e}")
        return text


class TTSHandler(BaseHTTPRequestHandler):
    """
    HTTP request handler for TTS requests.

    Endpoint: GET /say?t=<text>[&voice=<voice_name>]

    The Nabaztag firmware calls this with:
      GET /say?t=Hello%20World

    Optional voice parameter:
      GET /say?t=Hello&voice=fr_FR-tom-medium
    """

    def do_GET(self):
        """
        Handle GET requests to /say endpoint.

        Query parameters:
          - t: Text to speak (required)
          - voice: Voice name (optional, defaults to VOICE)
        """
        # Only accept /say endpoint
        if "/say" not in self.path.lower():
            self.send_response(404)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Not found")
            return

        # Parse URL and extract parameters
        parsed = urllib.parse.urlparse(self.path)
        params = dict(urllib.parse.parse_qsl(parsed.query))
        text = params.get("t", "")
        voice = params.get("voice", VOICE)  # Default from config

        if not text:
            self.send_response(400)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Missing 't' parameter")
            return

        # Convert text to phonemes if enabled
        piper_input = text
        if USE_PHONEMES:
            logger.info(f"Converting text to phonemes: '{text}'")
            piper_input = text_to_phonemes(text)
            logger.info(f"Phonemes: '{piper_input}'")

        logger.info(f"Processing TTS: '{text}' with voice={voice}")

        try:
            # Small delay to ensure Nabaztag is ready to receive
            time.sleep(0.1)

            # Build Piper command with all parameters
            # Note: Using --output_file - (writes WAV to stdout)
            #       NOT --output_raw (which outputs raw PCM without WAV header!)
            piper_cmd = [
                PIPER_BINARY,
                "-m",
                voice,  # Voice model name
                "--data-dir",
                VOICES_FOLDER,  # Voice files directory
                "-s",
                SPEAKER,  # Speaker index
                "--length-scale",
                LENGTH_SCALE,  # Speech speed
                "--noise-scale",
                NOISE_SCALE,  # Breathing noise
                "--noise-w-scale",
                NOISE_W_SCALE,  # Phoneme width noise
                "--volume",
                VOLUME,  # Volume boost
                "--sentence-silence",
                SENTENCE_SILENCE,  # Sentence gaps
                "--output_file",
                "-",  # Write WAV to stdout
            ]

            logger.debug(f"Piper command: {' '.join(piper_cmd)}")

            # Build FFmpeg command for transcoding
            # -f wav: Force WAV format for pipe input (from Piper)
            # highpass: Remove low rumble (small speaker can't reproduce)
            # treble: Boost high frequencies for speech clarity
            # volume: Boost output volume
            # -ar 16000: Resample to 16kHz
            # -ac 1: Mono
            # -acodec pcm_s16le: 16-bit PCM
            # -f s16le: Output raw signed 16-bit PCM (NOT WAV format)
            #           This avoids FFmpeg's streaming WAV issues (unknown size, LIST chunk)
            # Build filter chain based on USE_FFMPEG_FILTERS flag
            if USE_FFMPEG_FILTERS:
                filter_chain = f"highpass=f={FFMPEG_HIGH_PASS},treble=g={FFMPEG_TREBLE},volume={FFMPEG_VOLUME}"
            else:
                filter_chain = "anull"  # No filters, just pass through

            ffmpeg_cmd = [
                FFMPEG_BINARY,
                "-f",
                "wav",
                "-i",
                "-",  # Input from stdin (WAV format from Piper)
                "-af",
                filter_chain,  # Audio filters (or anull if disabled)
                "-ar",
                str(TARGET_SAMPLE_RATE),  # Sample rate
                "-ac",
                "1",  # Mono
                "-acodec",
                "pcm_s16le",  # 16-bit PCM
                "-f",
                "s16le",  # Output: raw signed 16-bit PCM (no WAV container!)
                "-",  # Output to stdout
            ]

            logger.debug(f"FFmpeg command: {' '.join(ffmpeg_cmd)}")

            # Launch Piper process
            piper_proc = subprocess.Popen(
                piper_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )

            # Launch FFmpeg process (if enabled)
            if USE_FFMPEG:
                # Capture stderr to debug FFmpeg issues
                ffmpeg_stderr = open("/tmp/ffmpeg_stderr.log", "w")
                ffmpeg_proc = subprocess.Popen(
                    ffmpeg_cmd,
                    stdin=piper_proc.stdout,
                    stdout=subprocess.PIPE,
                    stderr=ffmpeg_stderr,
                )
                # Allow piper to exit without blocking FFmpeg
                piper_proc.stdout.close()
                output_proc = ffmpeg_proc

                # Log FFmpeg startup
                logger.info(f"FFmpeg: Starting pipeline with filters: {filter_chain}")
            else:
                output_proc = piper_proc
                logger.info("FFmpeg disabled: using direct Piper output")

            # Send HTTP headers immediately (before generating audio)
            # IMPORTANT: No Transfer-Encoding: chunked!
            # The Nabaztag's HTTP/1.0 client doesn't handle chunked encoding.
            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            # Feed text to Piper and stream output
            piper_proc.stdin.write(text.encode("utf-8"))
            piper_proc.stdin.close()

            bytes_sent = 0

            if USE_FFMPEG:
                # Collect raw PCM output from FFmpeg (no WAV header)
                audio_data = b""
                for chunk in output_proc.stdout:
                    if chunk:
                        audio_data += chunk

                # Add proper WAV header to the raw PCM data
                wav_header = create_valid_wav_header(
                    len(audio_data), TARGET_SAMPLE_RATE
                )
                self.wfile.write(wav_header)
                self.wfile.flush()
                bytes_sent += len(wav_header)

                # Stream the audio data
                self.wfile.write(audio_data)
                self.wfile.flush()
                bytes_sent += len(audio_data)

                logger.info(f"FFmpeg: Added WAV header ({len(audio_data)} bytes PCM)")
            else:
                # Direct Piper output (already has valid WAV header)
                for chunk in output_proc.stdout:
                    if chunk:
                        self.wfile.write(chunk)
                        self.wfile.flush()  # Force immediate send to Nabaztag
                        bytes_sent += len(chunk)

            # Wait for processes to finish
            piper_proc.wait()
            if USE_FFMPEG:
                ffmpeg_proc.wait()
                # Log FFmpeg stderr for debugging
                ffmpeg_stderr.close()
                with open("/tmp/ffmpeg_stderr.log", "r") as f:
                    ffmpeg_output = f.read()
                if ffmpeg_output.strip():
                    logger.debug(f"FFmpeg stderr: {ffmpeg_output[:500]}")
                else:
                    logger.debug("FFmpeg stderr: (empty)")

            logger.info(f"Streamed {bytes_sent} bytes to Nabaztag")

        except (ConnectionResetError, BrokenPipeError, socket.error) as e:
            # Nabaztag disconnected before/during playback
            logger.warning(f"Client disconnected: {e}")
        except Exception as e:
            logger.error(f"TTS processing error: {e}", exc_info=True)
            if not self.wfile.closed:
                try:
                    self.send_response(500)
                    self.send_header("Content-Type", "text/plain")
                    self.end_headers()
                    self.wfile.write(f"Error: {e}".encode())
                except:
                    pass

    def log_message(self, format, *args):
        """Override to use our logger."""
        logger.info(format % args)


def main():
    """Main entry point for the TTS proxy server."""
    parser = argparse.ArgumentParser(
        description="Piper TTS Proxy for Nabaztag v2 - Direct Streaming"
    )
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind")
    parser.add_argument("--port", type=int, default=6790, help="Port (default: 6790)")
    parser.add_argument(
        "--ffmpeg", action="store_true", help="Enable FFmpeg processing (default)"
    )
    parser.add_argument(
        "--no-ffmpeg",
        action="store_true",
        help="Disable FFmpeg processing (direct Piper output)",
    )
    parser.add_argument(
        "--no-filters",
        action="store_true",
        help="Disable FFmpeg audio filters (keep resampling only)",
    )
    parser.add_argument(
        "--phonemes",
        action="store_true",
        help="Enable phoneme conversion via espeak-ng (IPA format for Piper)",
    )
    args = parser.parse_args()

    # CLI flags override environment variable
    global USE_FFMPEG
    global USE_FFMPEG_FILTERS
    global USE_PHONEMES
    if args.no_ffmpeg:
        USE_FFMPEG = False
    elif args.ffmpeg:
        USE_FFMPEG = True
    USE_FFMPEG_FILTERS = not args.no_filters
    USE_PHONEMES = args.phonemes

    server = HTTPServer((args.host, args.port), TTSHandler)

    print(f"[TTS] Piper TTS Proxy started on http://{args.host}:{args.port}")
    print(f"[TTS] Voice: {VOICE}")
    print(f"[TTS] Voices folder: {VOICES_FOLDER}")
    print(f"[TTS] Piper binary: {PIPER_BINARY}")
    print(
        f"[TTS] Piper params: length={LENGTH_SCALE}, noise={NOISE_SCALE}, "
        f"noise_w={NOISE_W_SCALE}, volume={VOLUME}, silence={SENTENCE_SILENCE}"
    )
    print(f"[TTS] FFmpeg enabled: {USE_FFMPEG}")
    if USE_FFMPEG:
        print(f"[TTS] FFmpeg filters: {USE_FFMPEG_FILTERS}")
        print(
            f"[TTS] FFmpeg params: volume={FFMPEG_VOLUME}, highpass={FFMPEG_HIGH_PASS}Hz, "
            f"treble={FFMPEG_TREBLE}dB, sample_rate={TARGET_SAMPLE_RATE}Hz"
        )
        print(f"[TTS] FFmpeg binary: {FFMPEG_BINARY}")
    print(f"[TTS] Phonemes enabled: {USE_PHONEMES}")
    print("[TTS] Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[TTS] Stopping...")
        server.shutdown()


if __name__ == "__main__":
    main()
