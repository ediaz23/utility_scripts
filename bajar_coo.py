#!/bin/python3.10
import os
import sys
import requests
import json
import re
import subprocess

url = sys.argv[1]

m = re.match(r'(https?://[^/]+)(.*)', url)
host, rest = m.groups()
url_api = f'{host}/api/v1{rest}'
result: list[dict] = []

if os.path.exists('post.json'):
    with open("post.json") as f:
        result = json.load(f)
else:
    offset = 0
    chunk = True
    while chunk:
        try:
            print(f'{url_api}/posts?o={offset}')
            r = requests.get(f'{url_api}/posts?o={offset}', headers={'Accept': 'text/css'}, timeout=10)
            r.raise_for_status()
            chunk = r.json()
        except Exception:
            chunk = []

        chunk = [] if isinstance(chunk, dict) else chunk
        result.extend(chunk)
        offset += 50

    with open('post.json', 'w') as f:
        json.dump(result, f, indent=4)

for r in result:
    if r['file'] and not r.get('ready'):
        try:
            print(f'{url_api}/post/{r["id"]}')
            r = requests.get(f'{url_api}/post/{r["id"]}', headers={'Accept': 'text/css'}, timeout=10)
            r.raise_for_status()
            data = r.json()
            okey = True
            for video in data['videos']:
                video_url = f'{video["server"]}/data/{video["path"]}'
                print(video_url)
                try:
                    subprocess.run(['wget', '-c', '-O', video['name'], video_url], check=True)
                except subprocess.CalledProcessError:
                    okey = False
                    print("wget falló")
            r['ready'] = okey
            with open('post.json', 'w') as f:
                json.dump(result, f, indent=4)
        except Exception as e:
            print(e)
