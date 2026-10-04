import urllib.request
import json
from app.config import settings

# Get token
req = urllib.request.Request(
    'http://localhost:8000/auth/login',
    data=b'{"username":"owner", "password":"owner123"}',
    headers={'Content-Type': 'application/json'}
)
resp = urllib.request.urlopen(req)
token = json.loads(resp.read().decode())['access_token']

# Fetch items
req2 = urllib.request.Request(
    'http://localhost:8000/items/',
    headers={'Authorization': 'Bearer ' + token}
)
resp2 = urllib.request.urlopen(req2)
raw_json = resp2.read().decode()

with open('items_output.txt', 'w') as f:
    f.write(raw_json)
