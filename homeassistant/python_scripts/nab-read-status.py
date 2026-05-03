import socket, re, time, json, sys

ip = sys.argv[1] if len(sys.argv) > 1 else '192.168.0.58'
keys = ['sleep_state', 'autoclock', 'autohalftime', 'autosurprise',
        'autotaichi', 'weather', 'traffic', 'pollution']
try:
    s = socket.socket()
    s.settimeout(3)
    s.connect((ip, 23))
    cmds = 'sleeping? . cr autoclock-enabled @ . cr autohalftime-enabled @ . cr autosurprise-enabled @ . cr autotaichi-enabled @ . cr info-weather @ . cr info-traffic @ . cr info-pollution @ . cr quit'
    s.send((cmds + '\r\n').encode())
    time.sleep(0.5)
    s.settimeout(0.5)
    try:
        d = s.recv(8192)
    except:
        d = b''
    s.close()
    vals = []
    for l in d.split(b'\n'):
        l = l.strip()
        if re.match(rb'^-?\d+$', l):
            vals.append(int(l))
        else:
            m = re.match(rb'\[\d+\] > (-?\d+)', l)
            if m:
                vals.append(int(m.group(1)))
    result = dict(zip(keys, vals + [-1] * (len(keys) - len(vals))))
    print(json.dumps(result))
except:
    print(json.dumps({k: -1 for k in keys}))
