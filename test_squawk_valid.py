#!/usr/bin/env python3
"""
Test with VALID octal squawk code (0-7 digits only)
VFR Squawk codes must be octal: each digit 0-7
"""

import requests
import json
import time

BASE_URL = "http://192.168.4.1"

def test_squawk(code, description):
    print(f"\n{'='*80}")
    print(f"Testing: {description}")
    print(f"Code: {code}")
    print('='*80)

    # Get current
    r = requests.get(f"{BASE_URL}/setup/?action=get", timeout=5)
    current = r.json()
    original = current['setup']['vfrSquawk']
    print(f"Original: {original}")

    # Update
    current['setup']['vfrSquawk'] = code
    r = requests.post(
        f"{BASE_URL}/setup/?action=set",
        headers={'Content-Type': 'application/json'},
        data=json.dumps(current),
        timeout=5
    )

    print(f"POST Response: {r.status_code} - {r.text}")

    # Verify
    time.sleep(0.5)
    r = requests.get(f"{BASE_URL}/setup/?action=get", timeout=5)
    new_value = r.json()['setup']['vfrSquawk']

    if new_value == code:
        print(f"✅ SUCCESS: Changed to {new_value}")

        # Restore original
        current['setup']['vfrSquawk'] = original
        requests.post(
            f"{BASE_URL}/setup/?action=set",
            headers={'Content-Type': 'application/json'},
            data=json.dumps(current),
            timeout=5
        )
        time.sleep(0.5)
        restored = requests.get(f"{BASE_URL}/setup/?action=get", timeout=5).json()['setup']['vfrSquawk']
        print(f"Restored to: {restored}")
    else:
        print(f"❌ FAILED: Value is {new_value}, not {code}")
        print(f"   (Device rejected the update)")

# Test cases
print("VFR Squawk Update Tests")
print("Note: Squawk codes are OCTAL - each digit must be 0-7")

test_squawk(1200, "ORIGINAL VALUE (baseline)")
test_squawk(1234, "VALID octal code (all digits 0-7)")
test_squawk(7777, "VALID octal code (maximum valid)")
test_squawk(7000, "VALID octal code (7 is valid in octal)")
test_squawk(1289, "INVALID octal code (contains 8 and 9)")
test_squawk(9999, "INVALID octal code (all 9s)")

print("\n" + "="*80)
print("Summary:")
print("  - Valid codes should update successfully")
print("  - Invalid codes (containing 8 or 9) should be rejected")
print("="*80)
