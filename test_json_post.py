#!/usr/bin/env python3
"""
Test JSON POST to SkyEcho device - Set VFR Squawk to 7000
"""

import requests
import json
import time

BASE_URL = "http://192.168.4.1"
TIMEOUT = 5

def get_current_config():
    """Fetch current configuration."""
    print("📥 Fetching current configuration...")
    r = requests.get(f"{BASE_URL}/setup/?action=get", timeout=TIMEOUT)
    if r.status_code == 200:
        config = r.json()
        print(f"✅ Current VFR Squawk: {config['setup']['vfrSquawk']}")
        return config
    else:
        print(f"❌ Failed to fetch config: {r.status_code}")
        return None

def set_vfr_squawk(new_squawk):
    """Update VFR Squawk via JSON POST."""
    # First, get current config
    current = get_current_config()
    if not current:
        return False

    # Modify only the VFR Squawk
    current['setup']['vfrSquawk'] = new_squawk

    print(f"\n📤 Sending updated configuration (VFR Squawk → {new_squawk})...")
    print(f"Payload:")
    print(json.dumps(current, indent=2))

    # POST to /setup/?action=set
    headers = {'Content-Type': 'application/json'}
    r = requests.post(
        f"{BASE_URL}/setup/?action=set",
        headers=headers,
        data=json.dumps(current),
        timeout=TIMEOUT
    )

    print(f"\n📨 Response:")
    print(f"Status Code: {r.status_code}")
    print(f"Headers: {dict(r.headers)}")
    print(f"Body: {r.text[:500] if r.text else '(empty)'}")

    if r.status_code == 200:
        print(f"\n✅ Successfully updated VFR Squawk to {new_squawk}")
        return True
    else:
        print(f"\n❌ Update failed with status {r.status_code}")
        return False

def verify_update(expected_squawk):
    """Verify the update by fetching config again."""
    print(f"\n🔍 Verifying update...")
    time.sleep(1)  # Give device a moment

    config = get_current_config()
    if config:
        actual_squawk = config['setup']['vfrSquawk']
        if actual_squawk == expected_squawk:
            print(f"✅ VERIFIED: VFR Squawk is now {actual_squawk}")
            return True
        else:
            print(f"❌ MISMATCH: Expected {expected_squawk}, got {actual_squawk}")
            return False
    return False

def main():
    print("╔" + "═" * 78 + "╗")
    print("║" + " SkyEcho JSON POST Test - Set VFR Squawk to 7000".center(78) + "║")
    print("╚" + "═" * 78 + "╝\n")

    # Show current value
    print("STEP 1: Get current configuration")
    print("-" * 80)
    current = get_current_config()
    if not current:
        print("❌ Cannot proceed without current config")
        return

    original_squawk = current['setup']['vfrSquawk']
    print(f"\nOriginal VFR Squawk: {original_squawk}")

    # Update to 7000
    print("\n" + "=" * 80)
    print("STEP 2: Update VFR Squawk to 7000")
    print("-" * 80)

    success = set_vfr_squawk(7000)

    if success:
        # Verify
        print("\n" + "=" * 80)
        print("STEP 3: Verify the change")
        print("-" * 80)
        verify_update(7000)

        # Restore original value
        print("\n" + "=" * 80)
        print(f"STEP 4: Restore original value ({original_squawk})")
        print("-" * 80)

        restore = set_vfr_squawk(original_squawk)
        if restore:
            verify_update(original_squawk)
            print("\n✅ Test complete - original value restored")
        else:
            print(f"\n⚠️  Failed to restore original value!")
            print(f"    You may need to manually set VFR Squawk back to {original_squawk}")
    else:
        print("\n❌ Update failed, no changes made")

if __name__ == "__main__":
    main()
