import socket, re, time, json, sys

ip = sys.argv[1] if len(sys.argv) > 1 else '192.168.0.58'
try:
    s = socket.socket()
    s.settimeout(5)
    s.connect((ip, 23))
    s.send(b'sleeping? . cr autoclock-enabled @ . cr autohalftime-enabled @ . cr autosurprise-enabled @ . cr autotaichi-enabled @ . cr info-weather @ . cr info-traffic @ . cr info-pollution @ . cr quit\n')
    time.sleep(0.3)
    d = b''
    while 1:
        try:
            c = s.recv(4096)
            if not c: break
            d += c
        except:
            break
    s.close()
    v = re.findall(rb'> (\d+)|(?<=\n)(\d+)(?=\n)', d)
    if v:
        vals = [int(a or b) for a, b in v[-8:]]
        print(json.dumps(dict(zip(['sleep_state', 'autoclock', 'autohalftime', 'autosurprise', 'autotaichi', 'weather', 'traffic', 'pollution'], vals))))
    else:
        print(json.dumps({'sleep_state': 0, 'autoclock': 0, 'autohalftime': 0, 'autosurprise': 0, 'autotaichi': 0, 'weather': 0, 'traffic': 0, 'pollution': 0}))
except:
    print(json.dumps({'sleep_state': 0, 'autoclock': 0, 'autohalftime': 0, 'autosurprise': 0, 'autotaichi': 0, 'weather': 0, 'traffic': 0, 'pollution': 0}))
