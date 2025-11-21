
import json
import base64
from openpyxl import Workbook
from datetime import datetime
from pathlib import Path

folder = Path('.')

all_errors: dict[list, str] = {}
for file_path in folder.glob('detail_*.json'):
    with file_path.open(encoding='utf-8') as f:
        try:
            data = json.load(f)
            info = {}
            client_id = None
            if 'webhook' in data['full_event']['path']:
                info['direction'] = 'to'
                client_id = data['full_event']['queryStringParameters']['token']
            else:
                info['direction'] = 'from'
                if 'client_id' in data['full_event']['headers']:
                    client_id = data['full_event']['headers']['client_id']
                elif data['full_event']['headers'].get('Authorization'):
                    client_id = base64.b64decode(data['full_event']['headers']['Authorization'][6:]).decode().split(':', 1)[0]
                else:
                    client_id = 'no_client'
            info['date'] = datetime.strptime(data['full_event']['requestContext']['requestTime'], "%d/%b/%Y:%H:%M:%S %z")
            info['req'] = f'{data["full_event"]["httpMethod"]} {data["full_event"]["path"]}'
            if isinstance(data['output_body'], str):
                info['error'] = data['output_body']
            else:
                if 'error' in data['output_body']:
                    info['error'] = data['output_body']['error'].strip()
                elif 'detail' in data['output_body']:
                    info['error'] = data['output_body']['detail'].strip()
                else:
                    info['error'] = 'no_error'

            info['detail'] = data.get('input_body')
            info['file'] = file_path.name
            info['client_id'] = client_id
            if client_id not in all_errors:
                all_errors[client_id] = []
            all_errors[client_id].append(info)
        except Exception as e:
            print(file_path.name)
            raise e


wb = Workbook()

ws1 = wb.active
ws1.title = "ResumenPorCliente"

ws1.append(["client_id", "error", "date", "req", "odoo", "file", "detail"])

clients_sorted = sorted(all_errors.items(), key=lambda kv: len(kv[1]), reverse=True)

for client_id, errors in clients_sorted:
    for e in sorted(errors, key=lambda x: (x["error"], x["date"])):
        ws1.append([
            client_id,
            e["error"],
            e["date"].strftime("%Y-%m-%d %H:%M:%S"),
            e["req"],
            e["direction"],
            e["file"],
            json.dumps(e["detail"], ensure_ascii=False) if isinstance(e["detail"], (dict, list)) else e["detail"]
        ])

# --------- Hoja 2: Todos los errores ordenados ---------
ws2 = wb.create_sheet("TodosOrdenados")
ws2.append(["date", "client_id", "error", "req", "odoo", "file", "detail"])

all_rows = [e for errors in all_errors.values() for e in errors]
all_rows.sort(key=lambda r: (r["date"], r["client_id"], r["error"]))
for r in all_rows:
    ws2.append([
        r["date"].strftime("%Y-%m-%d %H:%M:%S"),
        r["client_id"],
        r["error"],
        r["req"],
        r["direction"],
        e["file"],
        json.dumps(r["detail"], ensure_ascii=False) if isinstance(r["detail"], (dict, list)) else r["detail"]
    ])

wb.save("errores.xlsx")
