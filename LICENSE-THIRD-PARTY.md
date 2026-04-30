# Licences des dépendances tierces

Ce projet `nab-piper` utilise plusieurs outils et bibliothèques tierces, chacun sous sa propre licence.

## Composants intégrés ou modifiés

| Composant | Source | Licence | Usage |
|-----------|--------|---------|-------|
| **ServerlessNabaztag** | [andreax79/ServerlessNabaztag](https://github.com/andreax79/ServerlessNabaztag) | Fork public (aucune licence explicite) | Code firmware MTL/Forth modifié |

## Binaires invoqués (non liés)

Ces outils sont invoqués par le projet comme processus externes. Ils ne sont pas distribués avec le code source de `nab-piper`.

| Outil | Site | Licence |
|-------|------|---------|
| **Piper** | [github.com/OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl) | **GPL v3** |
| **Modèles de voix Piper** | [huggingface.co/rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices) | **CC BY-NC-SA 4.0** |
| **espeak-ng** | [github.com/espeak-ng/espeak-ng](https://github.com/espeak-ng/espeak-ng) | **GPL v3** |
| **FFmpeg** | [ffmpeg.org](https://ffmpeg.org) | **LGPL/GPL** (selon options de compilation) |
| **Coqui TTS** | [github.com/coqui-ai/TTS](https://github.com/coqui-ai/TTS) | **MIT** |

## API distantes

| Service | Licence |
|---------|---------|
| **open-meteo** | Non-commercial — [open-meteo.com](https://open-meteo.com) |

## Notes

- Les **modèles de voix Piper** sont sous licence **Creative Commons BY-NC-SA 4.0** (non-commercial). Pour un usage commercial, utilisez des voix sous licence différente ou entraînez vos propres modèles.
- Les outils **Piper**, **espeak-ng** et **FFmpeg** ne sont pas distribués avec ce projet. L'utilisateur doit les installer séparément (via `install.sh` ou manuellement).
