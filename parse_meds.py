import pandas as pd
import re

print('Loading Excel...')
df = pd.read_excel(r'C:\Users\Eddy\Downloads\PriceLists_Pharmacy.xlsx', usecols=[0])
df.columns = ['TitleName']
df = df.dropna()
raw = df['TitleName'].tolist()
print(f'Total rows: {len(raw)}')

exclude_kw = [
    'SUTURE','STENT','CATHETER','GUIDE WIRE','GUIDEWIRE','SYRINGE','NEEDLE',
    'CANNULA','GLOVE','MASK','GAUZE','BANDAGE','DRESSING','PLASTER','SPLINT',
    'PIPETTE','MICROPIPETTE','BLADE','SCALPEL','STAPLE','CLAMP','FORCEP',
    'SPECULUM','DILATOR','TROCAR','WIRE ','DRAIN ','BLOOD SET',
    'GOWN','DRAPE','SWAB','COTTON','TAPE','THERMOMETER','OXIMETER',
    'STRIP TEST','ANTIGEN KIT','RAPID TEST KIT','ERCP','STENT PUSHER',
    'BILIARY','LITHOTRIPTO','INFUSION SET','IV SET',
    'WHEELCHAIR','CRUTCH','WALKER','BRACE','COLLAR',
    'SPECIMEN','CONTAINER','BOTTLE','VIAL','AMPULE','AMPOULE',
]

def is_medication(name):
    upper = str(name).upper()
    return not any(kw in upper for kw in exclude_kw)

UNIT_PATTERN = re.compile(
    r'(\d+(?:\.\d+)?)\s*(Mg/Ml|Mcg/Ml|Mg/5Ml|Mg/2Ml|Mg/10Ml|Mg/Ml|Mg|Ml|Mcg|Miu|Mmol|Meq|Gm|Iu|G(?=\b))',
    re.IGNORECASE
)

def clean_name(name):
    name = str(name).strip()
    # Remove trailing junk: *, (, (), whitespace
    name = re.sub(r'[\s\*\(]+$', '', name)
    name = re.sub(r'\s+', ' ', name).strip()
    # Title case
    name = name.title()
    # Fix medical units back to lowercase/standard
    def fix_unit(m):
        num = m.group(1)
        unit = m.group(2).lower()
        if unit == 'iu':
            unit = 'IU'
        return num + unit
    name = UNIT_PATTERN.sub(fix_unit, name)
    return name.strip()

dart_path = r'C:\Users\Eddy\Projects\sanlam-chronic-care\app\lib\utils\medications_data.dart'
with open(dart_path, 'r', encoding='utf-8') as f:
    dart_content = f.read()
existing_lower = {m.lower() for m in re.findall(r"'([^']{2,}?)'", dart_content)}
print(f'Existing entries: {len(existing_lower)}')

meds = []
seen = set()
for n in raw:
    if not is_medication(n):
        continue
    cleaned = clean_name(n)
    if not cleaned or len(cleaned) < 4:
        continue
    key = cleaned.lower()
    if key in seen or key in existing_lower:
        continue
    seen.add(key)
    meds.append(cleaned)

print(f'New medications to add: {len(meds)}')
out_path = r'C:\Users\Eddy\Projects\sanlam-chronic-care\app\lib\utils\new_meds.txt'
with open(out_path, 'w', encoding='utf-8') as f:
    for m in meds:
        f.write(m + '\n')
print(f'Written to new_meds.txt')
print('First 10 samples:')
for m in meds[:10]:
    print(' ', m)
