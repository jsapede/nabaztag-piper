import socket, re, time, json, sys

ip = sys.argv[1] if len(sys.argv) > 1 else '192.168.0.58'
keys = ['sleep_state', 'autoclock', 'autohalftime', 'autosurprise',
        'autotaichi', 'weather', 'traffic', 'pollution']
try:
    s = socket.socket()
    s.settimeout(3)
    s.connect((ip, 23))
    s.send(b'status-all\r\n')
    time.sleep(0.3)
    s.settimeout(0.3)
    try:
        d = s.recv(8192)
    except:
        d = b''
    s.close()
    # Find the line with ">" which contains the values
    for l in d.split(b'\n'):
        if b'>' in l:
            vals = re.findall(rb'-?\d+', l.split(b'>')[1])
            if len(vals) >= 8:
                print(json.dumps(dict(zip(keys, [int(v) for v in vals[:8]]))))
                raise SystemExit(0)
    print(json.dumps({k: -1 for k in keys}))
except SystemExit:
    pass
except:
    print(json.dumps({k: -1 for k in keys}))
