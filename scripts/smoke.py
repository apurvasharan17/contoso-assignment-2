import json, sys, time, urllib.request
url, stage, version = sys.argv[1:]
for attempt in range(30):
    try:
        with urllib.request.urlopen(url + '/health', timeout=20) as response:
            body = json.load(response)
        if body == {'status': 'ok', 'environment': stage, 'version': version}:
            print('Smoke test passed:', body)
            break
        print('Waiting for expected release:', body)
    except Exception as exc:
        print('Waiting for application:', exc)
    time.sleep(10)
else:
    sys.exit('Smoke test failed: expected release did not become healthy.')
