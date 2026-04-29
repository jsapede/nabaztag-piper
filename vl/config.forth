\ Configuration variables for Serverless Nabaztag
\
\ L'IP du TTS est remplacee automatiquement par install.sh
\ via TTS_SERVER_IP et TTS_PORT dans .env

\ TTS Server address (modifie par install.sh)
" http://XXX.XXX.XXX.XXX:6790/say?t=" constant TTS-SERVER$

\ Authentication (disabled for open access)
\ "nabaztag" username !
\ "1af59a24e534a10f29b5b22136df221f" md5-password !

\ Auto-control flags (gérés par le firmware MTL, pas par des variables Forth)
