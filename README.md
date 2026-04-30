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

*La suite de cette documentation couvre l'installation, la configuration réseau, l'intégration Home Assistant, la compilation du firmware et le dépannage.*
