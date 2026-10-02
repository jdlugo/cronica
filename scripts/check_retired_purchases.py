#!/usr/bin/env python3
"""Verify the retired purchase offer cannot be reached or locally simulated."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
errors = []
for file in (root / 'Shared').rglob('*.swift'):
    source = file.read_text()
    if re.search(r'TipJarSetting|Product\.products\s*\(|\.purchase\s*\(', source):
        errors.append(str(file.relative_to(root)))
for file in (root / 'Story.xcodeproj/xcshareddata/xcschemes').glob('*.xcscheme'):
    if 'StoreKitConfigurationFileReference' in file.read_text():
        errors.append(str(file.relative_to(root)))
if errors:
    raise SystemExit('FAIL: purchase offering remains in ' + ', '.join(errors))
assert not (root / 'Shared/ProductList.plist').exists()
assert not (root / 'Shared/Cronica.storekit').exists()
print('PASS: no purchase UI, product requests, checkout calls or StoreKit launch fixture')
