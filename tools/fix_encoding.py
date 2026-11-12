#!/usr/bin/env python3
import re
import glob

mojibake_map = {
    'Ã¡': 'a', 'Ã©': 'e', 'Ã­': 'i', 'Ã³': 'o', 'Ãº': 'u',
    'Ã±': 'n', 'Ã"': 'O', 'Ã‰': 'E', 'Ã': 'A', 'Ãº': 'U',
    'Ãœ': 'U', 'Ã¿': 'y', 'Ã§': 'c', 'Ã¨': 'e', 'Ã ': 'a',
    'Â·': '.', 'Â¡': '!', 'â˜…': '*',
}

def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    original = content
    for bad, good in mojibake_map.items():
        content = content.replace(bad, good)
    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Fixed: ' + path)

dart_files = glob.glob('lib/**/*.dart', recursive=True)
for f in dart_files:
    fix_file(f)
print('Done')