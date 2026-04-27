import re

with open(r'C:\Users\Eddy\Projects\sanlam-chronic-care\app\lib\utils\new_meds.txt', 'r', encoding='utf-8') as f:
    lines = [l.strip() for l in f if l.strip()]

def extra_clean(name):
    # Remove trailing empty parens like ' ( )' or ' ()'
    name = re.sub(r'\s*\(\s*\)\s*$', '', name).strip()
    name = re.sub(r'\s*\(\s*$', '', name).strip()
    return name

skip_exact = {'oral suspension bp', 'bp tablets', 'bp capsules', 'injection bp', 'bp syrup',
              'oral suspension', 'tablets', 'capsules', 'injection', 'syrup', 'solution'}

cleaned = []
seen = set()
for name in lines:
    name = extra_clean(name)
    if not name or len(name) < 4:
        continue
    if name.lower() in skip_exact:
        continue
    key = name.lower()
    if key in seen:
        continue
    seen.add(key)
    cleaned.append(name)

print(f'Total unique meds: {len(cleaned)}')

# Write SQL
parts = ['-- Pharmacy medication catalog import (009)\n']
parts.append('INSERT INTO medications (name, is_active) VALUES\n')
values = []
for name in cleaned:
    escaped = name.replace("'", "''")
    values.append(f"  ('{escaped}', TRUE)")
parts.append(',\n'.join(values))
parts.append('\nON CONFLICT DO NOTHING;\n')

out_path = r'C:\Users\Eddy\Projects\sanlam-chronic-care\backend\src\db\migrations\009_pharmacy_medications.sql'
with open(out_path, 'w', encoding='utf-8') as f:
    f.write(''.join(parts))
print(f'Written to 009_pharmacy_medications.sql')
print('Samples:', cleaned[:5])
