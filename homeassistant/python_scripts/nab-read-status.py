import socket, time, json, sys, re

ip = sys.argv[1] if len(sys.argv) > 1 else ''
keys = ['sleep_state', 'autoclock', 'autohalftime', 'autosurprise',
        'autotaichi', 'weather', 'traffic', 'pollution',
        'info_auto_weather', 'info_auto_pollution', 'uptime']
result = {k: -1 for k in keys}
if re.match(r'^\d+\.\d+\.\d+\.\d+$', ip) and ip != '0.0.0.0':
    try:
        s = socket.socket()
        s.settimeout(3)
        s.connect((ip, 23))
        s.settimeout(0.5)
        try: s.recv(8192)
        except: pass
        s.settimeout(3)
        s.send(b'status-all\r\n')
        time.sleep(1.0)
        try: d = s.recv(8192)
        except: d = b''
        s.close()
        for l in d.split(b'\n'):
            parts = l.split()
            if len(parts) >= 8:
                try:
                    vals = [int(p) for p in parts[:len(keys)]]
                    result = dict(zip(keys[:len(vals)], vals))
                    break
                except: pass
    except: pass
print(json.dumps(result))
