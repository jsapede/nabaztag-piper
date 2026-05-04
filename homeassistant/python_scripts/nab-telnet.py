#!/usr/bin/env python3
"""
nab-telnet.py — Envoie une commande Forth au Nabaztag par telnet.
Usage: python3 nab-telnet.py <IP> "<commande forth>"

Exemples:
  python3 nab-telnet.py 192.168.0.58 "0 1 info-set"
  python3 nab-telnet.py 192.168.0.58 "sleeping? . cr"
  python3 nab-telnet.py 192.168.0.58 "1 autoclock-enabled !"
  python3 nab-telnet.py 192.168.0.58 "clear-info"
"""
import socket, sys, time, re

ip = sys.argv[1] if len(sys.argv) > 1 else ''
cmd = sys.argv[2] if len(sys.argv) > 2 else ''

if re.match(r'^\d+\.\d+\.\d+\.\d+$', ip) and ip != '0.0.0.0':
    s = socket.socket()
    s.settimeout(5)
    try:
        s.connect((ip, 23))
        s.send((cmd + '\r\n').encode())
        time.sleep(0.2)
    except Exception:
        pass
    finally:
        s.close()
