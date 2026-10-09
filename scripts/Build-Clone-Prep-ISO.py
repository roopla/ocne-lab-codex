from pathlib import Path
import sys
import uuid
import hashlib
root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'private' / 'python-tools'))
import pycdlib
script = root / 'scripts' / 'Prepare-Clone-Identity.sh'
text = script.read_text(encoding='utf-8')
for original in ('2e3fc9be-6c02-4e7d-b631-0ce61fb20dc9','c965ec77-36cb-40aa-aa61-95f3b008708c','1756d852-30cd-40b7-bdd0-49a5359ed499','d4404167-3980-4c69-ae11-9b1e7125446e'):
    variant = str(uuid.UUID(bytes=uuid.UUID(original).bytes_le))
    text = text.replace(original + ')', original + '|' + variant + ')')
script.write_text(text, encoding='utf-8', newline='\n')
iso_path = root / 'ISO' / 'ocne-clone-preparation.iso'
if iso_path.exists():
    raise SystemExit('Preparation ISO already exists; inspect before replacing.')
iso = pycdlib.PyCdlib()
iso.new(vol_ident='OCNEPREP')
iso.add_file(str(script), iso_path='/PREP.SH;1')
iso.write(str(iso_path))
iso.close()
print('Identity script SHA256: ' + hashlib.sha256(script.read_bytes()).hexdigest())
print('Preparation ISO SHA256: ' + hashlib.sha256(iso_path.read_bytes()).hexdigest())
print('Read-only preparation ISO: ' + str(iso_path))