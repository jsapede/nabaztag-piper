import socket, time, json, sys

ip = sys.argv[1] if len(sys.argv) > 1 else '192.168.0.58'
keys = ['sleep_state', 'autoclock', 'autohalftime', 'autosurprise',
        'autotaichi', 'weather', 'traffic', 'pollution']
result = {k: -1 for k in keys}
try:
    s = socket.socket()
    s.settimeout(3)
    s.connect((ip, 23))
    s.send(b'status-all\r\n')
    time.sleep(0.3)
    s.settimeout(0.3)
    try: d = s.recv(8192)
    except: d = b''
    s.close()
    for l in d.split(b'\n'):
        if b'>' not in l: continue
        parts = l.split(b'>')[1].split()
        if len(parts) >= 8:
            vals = [int(p) for p in parts[:8]]
            result = dict(zip(keys, vals))
            break
except: pass
print(json.dumps(result))
