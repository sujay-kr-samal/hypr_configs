#!/usr/bin/env python3
import sys
import json
import urllib.request
import urllib.parse
import re

def parse_timestamp(ts_str):
    try:
        parts = ts_str.split(':')
        minutes = float(parts[0])
        seconds = float(parts[1])
        return minutes * 60 + seconds
    except:
        return 0.0

def clean_name(name):
    name = re.sub(r'\s*[\(\]][Ff]eat\..*?[\)\]]', '', name)
    name = re.sub(r'\s*[\(\]][Ff]eaturing.*?[\)\]]', '', name)
    name = re.sub(r'\s*-\s*[Rr]emastered.*$', '', name)
    name = re.sub(r'\s*[\(\]][Rr]emastered.*?[\)\]]', '', name)
    name = re.sub(r'\s*-\s*[Ss]ingle\s*[Vv]ersion$', '', name)
    name = re.sub(r'\s*[\(\]][Ss]ingle.*?[\)\]]', '', name)
    return name.strip()

def fetch_lyrics(artist, track):
    attempts = [
        (artist, track),
        (clean_name(artist), clean_name(track))
    ]
    
    for a_name, t_name in attempts:
        if not t_name:
            continue
        query = urllib.parse.urlencode({
            'artist_name': a_name,
            'track_name': t_name
        })
        url = f"https://lrclib.net/api/get?{query}"
        req = urllib.request.Request(
            url,
            headers={'User-Agent': 'quickshell-lyrics/1.0 (https://github.com/sujay/quickshell)'}
        )
        try:
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode('utf-8'))
                    synced_lyrics = data.get('syncedLyrics')
                    plain_lyrics = data.get('plainLyrics')
                    
                    if synced_lyrics:
                        lines = []
                        for line in synced_lyrics.splitlines():
                            match = re.match(r'^\[(\d+:\d+(?:\.\d+)?)\]\s*(.*)$', line)
                            if match:
                                ts_str, text = match.groups()
                                lines.append({
                                    "time": parse_timestamp(ts_str),
                                    "text": text.strip()
                                })
                        if lines:
                            return {"synced": True, "lines": lines}
                            
                    if plain_lyrics:
                        lines = [{"time": 0.0, "text": line.strip()} for line in plain_lyrics.splitlines()]
                        return {"synced": False, "lines": lines}
        except urllib.error.HTTPError as e:
            if e.code == 404:
                continue
            return {"error": f"HTTP Error {e.code}"}
        except Exception as e:
            return {"error": str(e)}
            
    return {"error": "No lyrics found."}

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(json.dumps({"error": "No track info provided."}))
        sys.exit(1)
    artist = sys.argv[1]
    track = sys.argv[2]
    
    if not track or track == "No Track Playing":
        res = {"error": "No track playing."}
    else:
        res = fetch_lyrics(artist, track)
    print(json.dumps(res))
