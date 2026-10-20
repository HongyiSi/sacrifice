"""Decode downloaded client log lines. Usage: python read_client_diagnostics.py LOG [ROOM]."""
import json
import sys
from datetime import datetime, timezone, timedelta
from urllib.parse import unquote

zone = timezone(timedelta(hours=8))
for line in open(sys.argv[1], encoding='utf-8'):
    try:
        envelope = json.loads(line)
        row = json.loads(unquote(envelope['data']))
        state = row.get('state', {})
        if len(sys.argv) > 2 and state.get('room') != sys.argv[2]:
            continue
        timestamp = datetime.fromtimestamp(row['at']/1000, zone).isoformat(timespec='seconds')
        print(json.dumps({'time_cn':timestamp, 'server_time':envelope['time'], **row}, ensure_ascii=False))
    except (ValueError, KeyError, TypeError):
        continue
