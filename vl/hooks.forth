: on-click ( -- )  \ Click hook
nil "time=" :: time-ms :: str-join  \ payload
nil server-url @ :: "/hooks/click.php" :: str-join  \ url
http-post
drop drop ;

: on-dbl-click ( -- )  \ Double click hook
play-midi-ack
nil "time=" :: time-ms :: str-join  \ payload
nil server-url @ :: "/hooks/dblclick.php" :: str-join  \ url
http-post
drop drop ;

: on-ears ( -- )  \ Ears hook
play-midi-acquired
nil "left=" :: left-ear-position :: "&right=" :: right-ear-position :: str-join  \ payload
nil server-url @ :: "/hooks/ears.php" :: str-join  \ url
http-post
drop drop ;

: on-time ( -- )  \ Hour hook
sleeping? invert autoclock-enabled @ and if  \ if not sleeping AND clock enabled
nil server-url @ :: "/config/clock/" :: language @ :: "/" :: get-hour :: "/" :: 6 random 1 + :: ".mp3" :: str-join  \ url
play-url
then ;

: on-halftime ( -- )  \ Half-hour hook
sleeping? invert autohalftime-enabled @ and if  \ if not sleeping AND halftime enabled
nil server-url @ :: "/config/clockall/" :: language @ :: "/" :: "hg0" :: 12 random 1 + :: ".mp3" :: str-join  \ url
play-url
then ;

: on-rfid ( rfid -- )  \ RFID hook
>r
nil "tag=" :: >r :: str-join  \ payload
nil server-url @ :: "/hooks/rfid.php" :: str-join  \ url
http-post
drop drop ;

: say ( text --  )  \ Text to speech
sleeping? invert if  \ if not sleeping
url-encode >r
nil TTS-SERVER$ :: r> :: str-join \ url
play-url
then ;
