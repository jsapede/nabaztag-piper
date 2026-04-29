\ Configuration variables for Serverless Nabaztag
\
\ BEFORE RECOMPILATION:
\  1. Changer TTS-SERVER$ ci-dessous si le TTS est sur une autre machine
\  2. Changer language$ si besoin (fr/en/es/de/it)

\ TTS Server address (changez ici avant de recompiler)
" http://192.168.0.42:6790/say?t=" constant TTS-SERVER$

\ Language (fr = default)
" fr" constant LANGUAGE$

\ Authentication (disabled for open access)
\ "nabaztag" username !
\ "1af59a24e534a10f29b5b22136df221f" md5-password !

\ Auto-control flags (default: 1 = enabled)
1 variable autoclock-enabled       \ on-time clock (default: 1)
1 variable autohalftime-enabled   \ on-halftime clock (default: 1)
1 variable autosurprise-enabled  \ surprise sounds (default: 1)
1 variable autotaichi-enabled    \ taichi movements (default: 1)
