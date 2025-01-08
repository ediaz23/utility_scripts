#!/usr/bin/python3.10
import os
import argparse
from mutagen.easyid3 import EasyID3
from mutagen.mp3 import MP3
import pykakasi

# Inicializar pykakasi
kks = pykakasi.kakasi()


def kanji_to_romaji(text):
    '''Convierte texto en kanji a romaji.'''
    result = kks.convert(text)
    return ''.join([item['hepburn'] for item in result])


def process_mp3_files(directory, simulate):
    '''Procesa los archivos MP3 en la carpeta dada.'''
    for filename in os.listdir(directory):
        if filename.endswith('.mp3'):
            file_path = os.path.join(directory, filename)
            try:
                # Leer metadata del archivo MP3
                audio = MP3(file_path, ID3=EasyID3)
                track_num = audio.get('tracknumber', ['00'])[0].split('/')[0]
                title = audio.get('title', [None])[0]

                if title:
                    # Detectar si el título está en kanji y convertirlo
                    romaji_title = kanji_to_romaji(title) if any('\u4e00' <= char <= '\u9fff' for char in title) else title
                    romaji_title = romaji_title.title()
                    new_filename = f'{track_num.zfill(2)}. {romaji_title}.mp3'
                    new_file_path = os.path.join(directory, new_filename)

                    print(f'Procesado: {filename} -> {new_filename}')

                    if not simulate:
                        # Actualizar metadatos y renombrar archivo
                        audio['title'] = romaji_title
                        audio.save()
                        os.rename(file_path, new_file_path)
                else:
                    print(f'Saltando: {filename} (sin título en metadatos)')
            except Exception as e:
                print(f'Error procesando {filename}: {e}')


# Manejo de argumentos
parser = argparse.ArgumentParser(description='Convierte títulos en Kanji a Romanji en archivos MP3.')
parser.add_argument('directory', nargs='?', default=os.getcwd(), help='Directorio con los archivos MP3 (por defecto, el actual).')
parser.add_argument('-s', '--save', action='store_true', help='Realiza los cambios en lugar de solo mostrarlos.')
args = parser.parse_args()

# Procesar los archivos
process_mp3_files(args.directory, not args.save)
