#!/usr/bin/env python3
"""
Test script to probe SkyEcho device JSON API endpoints.
Run this while connected to the SkyEcho WiFi network.
"""

import requests
import json
from datetime import datetime

BASE_URL = "http://192.168.4.1"
TIMEOUT = 5

def print_section(title):
    print("\n" + "=" * 80)
    print(f"  {title}")
    print("=" * 80)

def test_landing_page():
    """Test basic connectivity with landing page."""
    print_section("1. Testing Landing Page (GET /)")
    try:
        r = requests.get(f"{BASE_URL}/", timeout=TIMEOUT)
        print(f"Status: {r.status_code}")
        print(f"Content-Type: {r.headers.get('content-type')}")
        print(f"Content-Length: {len(r.content)} bytes")
        print(f"Cookies: {r.cookies.get_dict()}")

        if r.status_code == 200:
            print("✅ Landing page accessible")
            # Check for status table
            if "Current Status" in r.text:
                print("✅ Found 'Current Status' table")
            if "ICAO Address" in r.text:
                print("✅ Found 'ICAO Address' field")
        else:
            print(f"❌ Unexpected status code: {r.status_code}")

        return r.status_code == 200
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection failed: {e}")
        return False

def test_setup_page_html():
    """Test setup page HTML version."""
    print_section("2. Testing Setup Page HTML (GET /setup)")
    try:
        r = requests.get(f"{BASE_URL}/setup", timeout=TIMEOUT)
        print(f"Status: {r.status_code}")
        print(f"Content-Type: {r.headers.get('content-type')}")
        print(f"Content-Length: {len(r.content)} bytes")

        if r.status_code == 200:
            print("✅ Setup page accessible")

            # Check for form elements
            checks = [
                ("Apply button", 'value="Apply"' in r.text),
                ("ICAO Address input", 'name="icaoAddress"' in r.text),
                ("Callsign input", 'name="callsign"' in r.text),
                ("Receiver mode radio", 'name="pingControlState"' in r.text),
                ("JavaScript present", 'function sendSettings' in r.text),
            ]

            for check_name, check_result in checks:
                status = "✅" if check_result else "❌"
                print(f"{status} {check_name}")

        return r.status_code == 200
    except requests.exceptions.RequestException as e:
        print(f"❌ Connection failed: {e}")
        return False

def test_json_get_endpoint():
    """Test JSON GET endpoint for current config."""
    print_section("3. Testing JSON GET Endpoint (GET /setup/?action=get)")
    try:
        r = requests.get(f"{BASE_URL}/setup/?action=get", timeout=TIMEOUT)
        print(f"Status: {r.status_code}")
        print(f"Content-Type: {r.headers.get('content-type')}")
        print(f"Content-Length: {len(r.content)} bytes")

        if r.status_code == 200:
            try:
                data = r.json()
                print("✅ Valid JSON response received")
                print("\nJSON Structure:")
                print(json.dumps(data, indent=2))

                # Analyze structure
                print("\n--- Structure Analysis ---")
                if 'setup' in data:
                    print(f"✅ 'setup' object found with {len(data['setup'])} fields:")
                    for key in sorted(data['setup'].keys()):
                        value = data['setup'][key]
                        value_type = type(value).__name__
                        print(f"   - {key}: {value} ({value_type})")

                if 'ownshipFilter' in data:
                    print(f"\n✅ 'ownshipFilter' object found:")
                    for key, value in data['ownshipFilter'].items():
                        value_type = type(value).__name__
                        print(f"   - {key}: {value} ({value_type})")

                # Save to file
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"device_config_{timestamp}.json"
                with open(filename, 'w') as f:
                    json.dump(data, f, indent=2)
                print(f"\n✅ Saved response to: {filename}")

                return True
            except json.JSONDecodeError as e:
                print(f"❌ Invalid JSON response: {e}")
                print(f"Raw content: {r.text[:500]}")
                return False
        else:
            print(f"❌ Unexpected status code: {r.status_code}")
            print(f"Response: {r.text[:200]}")
            return False

    except requests.exceptions.RequestException as e:
        print(f"❌ Connection failed: {e}")
        return False

def test_alternate_endpoints():
    """Test other possible JSON endpoints."""
    print_section("4. Testing Alternate Endpoints")

    endpoints = [
        "/setup?action=get",        # Without slash before ?
        "/api/setup",                # REST-style
        "/api/config",               # REST-style
        "/setup/config",             # REST-style
        "/config",                   # Simple
        "/?action=get",              # Root with action
    ]

    for endpoint in endpoints:
        try:
            r = requests.get(f"{BASE_URL}{endpoint}", timeout=2)
            if r.status_code == 200:
                try:
                    data = r.json()
                    print(f"✅ {endpoint} returns JSON!")
                    print(f"   Keys: {list(data.keys())}")
                except:
                    print(f"⚠️  {endpoint} returns {r.status_code} but not JSON")
            else:
                print(f"   {endpoint} → {r.status_code}")
        except:
            print(f"   {endpoint} → connection failed")

def test_json_structure_mapping():
    """Map JSON fields to HTML form fields."""
    print_section("5. JSON to HTML Field Mapping")

    try:
        r = requests.get(f"{BASE_URL}/setup/?action=get", timeout=TIMEOUT)
        if r.status_code != 200:
            print("❌ Could not fetch JSON config")
            return

        data = r.json()
        setup = data.get('setup', {})

        # Known mappings from JavaScript
        mappings = {
            'icaoAddress': ('icaoAddress', 'hex', 'ICAO Address (hex)'),
            'callsign': ('callsign', 'string', 'Callsign'),
            'emitterCategory': ('emitterCategory', 'int', 'Emitter Category'),
            'adsbInCapability': ('adsbInCapability', 'bitmask', 'ADS-B In Capability'),
            'control': ('pingControlState', 'bitmask', 'Receiver Mode + 1090ES Tx'),
            'vfrSquawk': ('vfrSquawk', 'int', 'VFR Squawk'),
            'aircraftLengthWidth': (None, 'packed', 'Aircraft Length + Width (packed)'),
            'gpsAntennaOffset': (None, 'packed', 'GPS Antenna Offset (packed)'),
            'stallSpeed': ('stallSpeed', 'encoded', 'Stall Speed (encoded)'),
            'SIL': (None, 'const', 'SIL (always 1)'),
            'SDA': ('SDA', 'int', 'SDA'),
        }

        print("\nJSON Field → HTML Field Mapping:")
        print(f"{'JSON Field':<25} {'Value':<15} {'Type':<10} {'HTML Field/Description'}")
        print("-" * 90)

        for json_field, (html_field, field_type, description) in mappings.items():
            value = setup.get(json_field, 'N/A')

            # Format value based on type
            if field_type == 'hex' and value != 'N/A':
                formatted_value = f"{value} (0x{value:06X})"
            else:
                formatted_value = str(value)

            html_info = html_field if html_field else description
            print(f"{json_field:<25} {formatted_value:<15} {field_type:<10} {html_info}")

        # Ownship filter
        print("\nOwnship Filter:")
        ownship = data.get('ownshipFilter', {})
        for key, value in ownship.items():
            if value is not None and key == 'icaoAddress':
                print(f"  {key}: {value} (0x{value:06X})")
            elif value is not None and key == 'flarmId':
                print(f"  {key}: {value} (0x{value:06X})")
            else:
                print(f"  {key}: {value}")

    except Exception as e:
        print(f"❌ Error: {e}")

def main():
    print("╔" + "═" * 78 + "╗")
    print("║" + " SkyEcho Device JSON API Test Script".center(78) + "║")
    print("╚" + "═" * 78 + "╝")
    print(f"\nDevice URL: {BASE_URL}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Run tests
    landing_ok = test_landing_page()
    if not landing_ok:
        print("\n❌ Cannot reach device. Please ensure you are connected to SkyEcho WiFi network.")
        return

    setup_html_ok = test_setup_page_html()
    json_ok = test_json_get_endpoint()

    if json_ok:
        test_json_structure_mapping()

    test_alternate_endpoints()

    # Summary
    print_section("Summary")
    print(f"Landing Page:     {'✅ OK' if landing_ok else '❌ FAIL'}")
    print(f"Setup Page HTML:  {'✅ OK' if setup_html_ok else '❌ FAIL'}")
    print(f"JSON GET API:     {'✅ OK' if json_ok else '❌ FAIL'}")

    if json_ok:
        print("\n🎉 SUCCESS: Device has JSON API available!")
        print("   You can use GET /setup/?action=get to fetch config as JSON")
        print("   You can use POST /setup/?action=set to update config as JSON")
        print("\n   This means Phase 5 can be MUCH simpler - no HTML parsing needed!")
    else:
        print("\n⚠️  JSON API not available or different structure than expected.")
        print("   Will need to rely on HTML form scraping approach.")

if __name__ == "__main__":
    main()
