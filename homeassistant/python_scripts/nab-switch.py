#!/usr/bin/env python3
"""
nab-switch.py — Handler central pour command_line switches Nabaztag.

Usage: python3 nab-switch.py <feature> <action>
  feature: clock, halftime, surprise, taichi, weather, traffic, pollution, nose
  action:  on, off

L'IP est hardcodée — injectée par le script d'install (Makefile).
Pas de dépendance au rendering de templates HA.
"""
import socket, time, sys, urllib.request

IP = '192.168.0.58'

FLAG_CMD = {
    'clock': 'autoclock-enabled !',
    'halftime': 'autohalftime-enabled !',
    'surprise': 'autosurprise-enabled !',
    'taichi': 'autotaichi-enabled !',
}

SLOT_MAP = {'weather': 1, 'traffic': 3, 'pollution': 7}
KEY_ORDER = ['sleep_state','autoclock','autohalftime','autosurprise','autotaichi','weather','traffic','pollution']
DEFAULT_VALS = {'weather': 1, 'traffic': 3, 'pollution': 1}


def telnet(cmd):
    try:
        s = socket.socket(); s.settimeout(5)
        s.connect((IP, 23)); s.send((cmd + '\r\n').encode())
        time.sleep(0.2)
    except:
        pass
    finally:
        s.close()


def read_status():
    r = {k: -1 for k in KEY_ORDER}
    try:
        s = socket.socket(); s.settimeout(3)
        s.connect((IP, 23)); s.send(b'status-all\r\n')
        time.sleep(0.3); s.settimeout(0.3)
        try: d = s.recv(8192)
        except: d = b''
        s.close()
        for ln in d.split(b'\n'):
            if b'>' not in ln: continue
            p = ln.split(b'>')[1].split()
            if len(p) >= 8:
                r = dict(zip(KEY_ORDER, [int(x) for x in p[:8]])); break
    except:
        pass
    return r


if len(sys.argv) < 3:
    sys.exit(1)

feature = sys.argv[1]
action = sys.argv[2]

if feature in FLAG_CMD:
    val = '1' if action == 'on' else '0'
    telnet(f"{val} {FLAG_CMD[feature]}")

elif feature in SLOT_MAP:
    slot = SLOT_MAP[feature]
    if action == 'on':
        st = read_status()
        cur = st.get(feature, -1)
        if cur == -1:
            cur = DEFAULT_VALS[feature]
        telnet(f"{cur} {slot} info-set")
    else:
        st = read_status()
        telnet("clear-info")
        time.sleep(0.3)
        for feat, sl in SLOT_MAP.items():
            if feat == feature: continue
            v = st.get(feat, -1)
            if v != -1:
                telnet(f"{v} {sl} info-set")
                time.sleep(0.1)

elif feature == 'nose':
    val = 3 if action == 'on' else 0
    try:
        urllib.request.urlopen(f"http://{IP}/nose?v={val}", timeout=5)
    except:
        pass
