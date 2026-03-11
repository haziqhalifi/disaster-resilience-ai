#!/usr/bin/env python3
"""Test script to trigger an emergency warning and broadcast notifications."""

import requests
import json
from datetime import datetime, timedelta

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

API_BASE_URL = "http://localhost:8000"
API_ENDPOINT = f"{API_BASE_URL}/api/v1/warnings"

# Get or create a test auth token (you may need to login first)
# For now, we'll assume you're using an admin/system token
AUTH_TOKEN = "your-jwt-token-here"  # Replace with actual token

# ═══════════════════════════════════════════════════════════════════════════
# Test Data
# ═══════════════════════════════════════════════════════════════════════════

# Selangor coordinates (central area for testing)
TEST_WARNINGS = [
    {
        "title": "🚨 FLOOD ALERT - Cyberjaya Main Road",
        "description": "DANGEROUS FLOOD CONDITION: Heavy flooding reported on main highway. Water level rising rapidly. Evacuate to higher ground immediately. Emergency services en route.",
        "hazard_type": "flood",
        "alert_level": "warning",
        "location": {
            "latitude": 3.1390,
            "longitude": 101.6869
        },
        "radius_km": 5.0,
        "source": "test-system"
    },
    {
        "title": "🔴 EVACUATION - Selangor Flash Flood",
        "description": "IMMEDIATE EVACUATION REQUIRED: Flash flooding in Selangor area. All residents must evacuate to designated shelter areas. Contact emergency services: 03-xxxx-xxxx",
        "hazard_type": "flood",
        "alert_level": "evacuate",
        "location": {
            "latitude": 3.0738,
            "longitude": 101.5186
        },
        "radius_km": 10.0,
        "source": "test-system"
    },
    {
        "title": "⚠️ TYPHOON WARNING - Klang Valley",
        "description": "Strong winds and heavy rainfall expected. Secure loose items. Stay indoors. Keep emergency contact numbers handy.",
        "hazard_type": "typhoon",
        "alert_level": "observe",
        "location": {
            "latitude": 3.0355,
            "longitude": 101.5244
        },
        "radius_km": 15.0,
        "source": "test-system"
    }
]

# ═══════════════════════════════════════════════════════════════════════════
# Main Test Function
# ═══════════════════════════════════════════════════════════════════════════

def test_create_warning(warning_data: dict):
    """Create a single test warning and broadcast it."""
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {AUTH_TOKEN}"  # Add token if backend requires auth
    }
    
    print(f"\n{'='*70}")
    print(f"Testing Warning: {warning_data['title']}")
    print(f"{'='*70}")
    print(f"Location: {warning_data['location']}")
    print(f"Radius: {warning_data['radius_km']} km")
    print(f"Alert Level: {warning_data['alert_level'].upper()}")
    print(f"\nSending request to: {API_ENDPOINT}")
    
    try:
        response = requests.post(
            API_ENDPOINT,
            json=warning_data,
            headers=headers,
            timeout=10
        )
        
        print(f"\n✓ Response Status: {response.status_code}")
        
        if response.status_code in [200, 201]:
            result = response.json()
            print(f"✓ SUCCESS - Warning created and broadcasted!")
            print(f"\n📊 Broadcast Results:")
            print(f"  • Warning ID: {result.get('warning_id')}")
            print(f"  • Push Notifications Sent: {result.get('push_sent', 0)}")
            print(f"  • SMS Alerts Sent: {result.get('sms_sent', 0)}")
            print(f"  • Total Affected Users: {result.get('total_affected', 0)}")
            return True
        else:
            print(f"✗ FAILED - Status {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"✗ ERROR: Cannot connect to {API_BASE_URL}")
        print(f"  Make sure backend is running:")
        print(f"  cd backend_fastapi")
        print(f"  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000")
        return False
    except Exception as e:
        print(f"✗ ERROR: {str(e)}")
        return False

# ═══════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("\n" + "="*70)
    print("DISASTER RESILIENCE AI - EMERGENCY WARNING TEST")
    print("="*70)
    
    # Check backend connection
    try:
        health = requests.get(f"{API_BASE_URL}/docs", timeout=5)
        print(f"✓ Backend is running at {API_BASE_URL}")
    except:
        print(f"✗ Backend NOT running at {API_BASE_URL}")
        print(f"\nStart backend with:")
        print(f"  cd backend_fastapi")
        print(f"  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000")
        exit(1)
    
    # Test each warning
    print(f"\n\nAvailable test warnings:")
    for i, w in enumerate(TEST_WARNINGS, 1):
        print(f"  {i}. {w['title']} ({w['alert_level'].upper()})")
    
    print(f"\nTesting: ALL WARNINGS")
    
    success_count = 0
    for warning in TEST_WARNINGS:
        if test_create_warning(warning):
            success_count += 1
    
    print(f"\n\n{'='*70}")
    print(f"RESULTS: {success_count}/{len(TEST_WARNINGS)} warnings sent successfully")
    print(f"{'='*70}\n")
    
    if success_count == len(TEST_WARNINGS):
        print("✓ All test warnings sent!")
        print("\n📱 Check your app or check backend logs for notification delivery:")
        print("  SMS: Check Twilio logs / phone for SMS")
        print("  Push: Check Firebase Console / app notifications")
    else:
        print("✗ Some warnings failed. Check errors above.")
