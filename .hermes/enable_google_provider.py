import json
import urllib.request
import urllib.error
from pathlib import Path

ENV = Path('.env')
vals = {}
for line in ENV.read_text(encoding='utf-8').splitlines():
    if line and not line.lstrip().startswith('#') and '=' in line:
        k, v = line.split('=', 1)
        vals[k.strip()] = v.strip()

required = ['SUPABASE_URL', 'SUPABASE_ACCESS_TOKEN', 'GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET']
missing = [k for k in required if not vals.get(k)]
if missing:
    print('MISSING ' + ','.join(missing))
    raise SystemExit(1)

ref = vals['SUPABASE_URL'].split('//', 1)[1].split('.', 1)[0]
url = f'https://api.supabase.com/v1/projects/{ref}/config/auth'
headers = {
    'Authorization': 'Bearer ' + vals['SUPABASE_ACCESS_TOKEN'],
    'Content-Type': 'application/json',
    'User-Agent': 'HermesAgent/1.0',
}

payload = {
    'external_google_enabled': True,
    'external_google_client_id': vals['GOOGLE_CLIENT_ID'],
    'external_google_secret': vals['GOOGLE_CLIENT_SECRET'],
    'site_url': 'https://fisher-go.app',
    'uri_allow_list': 'https://fisher-go.app,https://www.fisher-go.app',
}

req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers, method='PATCH')
try:
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = resp.read().decode()
        status = resp.status
except urllib.error.HTTPError as e:
    print('PATCH_FAILED', e.code, e.read().decode(errors='replace')[:1000])
    raise SystemExit(1)

print(f'PATCH_OK status={status} ref={ref}')

# Verify with a fresh GET
req = urllib.request.Request(url, headers=headers, method='GET')
try:
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read().decode())
except urllib.error.HTTPError as e:
    print('VERIFY_GET_FAILED', e.code, e.read().decode(errors='replace')[:1000])
    raise SystemExit(1)

safe = {
    'external_google_enabled': data.get('external_google_enabled'),
    'external_google_client_id': 'present' if data.get('external_google_client_id') else None,
    'external_google_secret': 'present' if data.get('external_google_secret') else None,
    'site_url': data.get('site_url'),
    'uri_allow_list': data.get('uri_allow_list'),
}
print(json.dumps(safe, ensure_ascii=False, indent=2))
