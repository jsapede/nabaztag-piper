#!/usr/bin/env python3
"""
Coqui TTS CLI Wrapper — lit stdin, ecrit WAV sur stdout
Compatible avec le pipeline Piper (subprocess stdin/stdout/FFmpeg).

Usage:
  echo "Bonjour" | python3 coqui_cli.py --model vits > audio.wav
  echo "Hello" | python3 coqui_cli.py --model xtts --speaker Frederic > audio.wav

Variables d'environnement (via .env) :
  COQUI_MODEL=vits         # vits | xtts
  COQUI_SPEAKER=Frederic   # voix XTTS (ignore si vits)
  COQUI_LANGUAGE=fr        # langue XTTS
"""

import argparse
import io
import os
import sys

import numpy as np
import soundfile as sf

MODEL_CACHE = {}


def get_tts(model_name: str):
    """Charge et met en cache le modele TTS."""
    key = model_name
    if key not in MODEL_CACHE:
        from TTS.api import TTS
        MODEL_CACHE[key] = TTS(model_name)
    return MODEL_CACHE[key]


def main():
    parser = argparse.ArgumentParser(description="Coqui TTS CLI — stdin vers WAV stdout")
    parser.add_argument("--model", default=None,
                        help="Modele Coqui (defaut: COQUI_MODEL env)")
    parser.add_argument("--speaker", default=None,
                        help="Speaker XTTS (defaut: COQUI_SPEAKER env)")
    parser.add_argument("--language", default=None,
                        help="Langue XTTS (defaut: COQUI_LANGUAGE env)")
    args = parser.parse_args()

    model_name = args.model or os.environ.get("COQUI_MODEL", "vits")
    speaker = args.speaker or os.environ.get("COQUI_SPEAKER", "")
    language = args.language or os.environ.get("COQUI_LANGUAGE", "fr")

    # Mapper les noms courts vers les modeles Coqui
    model_map = {
        "vits": "tts_models/fr/css10/vits",
        "xtts": "tts_models/multilingual/multi-dataset/xtts_v2",
    }
    full_model = model_map.get(model_name, model_name)

    # Lire le texte depuis stdin
    text = sys.stdin.read().strip()
    if not text:
        print("Erreur: texte vide sur stdin", file=sys.stderr)
        sys.exit(1)

    # Charger le modele (en cache)
    tts = get_tts(full_model)

    # Generer l'audio
    kwargs = {"text": text}
    if "xtts" in full_model and speaker:
        kwargs["speaker"] = speaker
        kwargs["language"] = language
    elif "xtts" in full_model:
        kwargs["language"] = language

    wav = tts.tts(**kwargs)
    wav_np = np.array(wav, dtype=np.float32)

    # Sample rate selon le modele
    sr = getattr(tts.synthesizer.tts_model.config, "audio", {}).get("sample_rate", 22050)
    if sr is None:
        sr = 22050

    # Ecrire WAV sur stdout (buffer pour eviter les entrees dans le fichier)
    buf = io.BytesIO()
    sf.write(buf, wav_np, sr, format="WAV", subtype="PCM_16")
    sys.stdout.buffer.write(buf.getvalue())
    sys.stdout.buffer.flush()


if __name__ == "__main__":
    main()
