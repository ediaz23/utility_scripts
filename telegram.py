
import os
import json
from telethon import TelegramClient


api_id = ''
api_hash = ''
name = ''
channel_name = ''


client = TelegramClient(name, api_id, api_hash)


def load_json(filename) -> dict:
    data = {'message_ids': []}
    try:
        with open(filename, 'r') as file:
            data = json.load(file)
    except FileNotFoundError:
        pass
    return data


def save_json(filename, data):
    try:
        with open(filename, 'w') as file:
            json.dump(data, file, indent=2)
    except Exception as e:
        print(f"Error al guardar el JSON: {e}")


async def process(channel_name: str, data: dict, filename):
    channel_id = None
    async for dialog in client.iter_dialogs():
        # if dialog.is_channel and dialog.name == channel_name:
        if dialog.name == channel_name:
            channel_id = dialog.id
            break
    if channel_id:
        async for message in client.iter_messages(channel_id):
            if message.media and message.id not in data['message_ids']:
                print(f'Messaje {message.id} {message.file.name}')
                path = await client.download_media(message, progress_callback=callback)
                print(f"Messaje {message.id} descargada: {path}")
                data['message_ids'].append(message.id)
                save_json(filename, data)
    else:
        print(f'channel not found {channel_name}')
    print('terminó')


async def main():
    filename = 'data.json'
    data = {}
    try:
        data = load_json(filename)
        await process(channel_name, data, filename)
        if os.path.exists(filename):
            os.remove(filename)
    except Exception as e:
        save_json(filename, data)
        raise e


def callback(current, total):
    print('Processing', current, 'out of', total,
          'bytes: {:.2%}'.format(current / total), end='\r')


with client:
    client.loop.run_until_complete(main())
