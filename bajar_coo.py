#!/bin/python3.10
import os
import sys
import requests
import json
import re
import subprocess
import time


def download_url(video_url, name) -> bool:
    try_count = 0
    okey = True
    while try_count < 5:
        print(video_url)
        try:
            subprocess.run(['wget', '-c', '-O', name, video_url], check=True)
            try_count = 5
        except subprocess.CalledProcessError:
            print("wget falló")
            try_count += 1
            if try_count < 5:
                time.sleep(3)
            else:
                okey = False
    return okey


url = sys.argv[1]
target = sys.argv[2] if len(sys.argv) > 2 else 'video'

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
            res = requests.get(f'{url_api}/posts?o={offset}', headers={'Accept': 'text/css'}, timeout=10)
            res.raise_for_status()
            chunk = res.json()
        except Exception:
            chunk = []

        chunk = [] if isinstance(chunk, dict) else chunk
        result.extend(chunk)
        offset += 50

    with open('post.json', 'w') as f:
        json.dump(result, f, indent=4)

for item in result:
    if item['file'] and not item.get('ready'):
        try:
            print(f'{url_api}/post/{item["id"]}')
            res = requests.get(f'{url_api}/post/{item["id"]}', headers={'Accept': 'text/css'}, timeout=10)
            res.raise_for_status()
            data = res.json()
            image_okey = True
            if target in ('image', 'all'):
                for image in data['previews']:
                    image_okey = download_url(f'{image["server"]}/data{image["path"]}', image['name'])

            video_okey = True
            if target in ('video', 'all'):
                for video in data['videos']:
                    video_okey = download_url(f'{video["server"]}/data{video["path"]}', video['name'])
            item['ready'] = image_okey and video_okey
            with open('post.json', 'w') as f:
                json.dump(result, f, indent=4)
        except Exception as e:
            print(e)
