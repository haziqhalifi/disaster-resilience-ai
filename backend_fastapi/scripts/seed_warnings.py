"""Seed the Supabase `warnings` table with sample hyper-local warnings.

Run from the backend_fastapi directory:
    python -m scripts.seed_warnings
"""

import sys
import os

# Allow imports from the app package
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.warnings import create_warning


SAMPLE_WARNINGS = [
    {
        "title": "Flood Warning: Kg. Banjir",
        "description": "Water levels rising rapidly at Sungai Lembing. Current level at 2.5m.",
        "hazard_type": "flood",
        "alert_level": "warning",
        "latitude": 3.8100,
        "longitude": 103.3280,
        "radius_km": 5.0,
        "source": "MET Malaysia",
    },
    {
        "title": "Dengkil: Heavy Rain Forecast",
        "description": "Weather forecast indicates 80% chance of heavy precipitation in Dengkil district "
                       "over the next 3 hours. Residents near Sungai Langat should monitor water levels. "
                       "Potential for minor flash floods in Salak Tinggi areas.",
        "hazard_type": "forecast",
        "alert_level": "advisory",
        "latitude": 2.8590,
        "longitude": 101.6780,
        "radius_km": 15.0,
        "source": "MET Malaysia",
    },
    {
        "title": "AID: Food & Supply Distribution",
        "description": "Social Welfare Dept (JKM) is distributing dry food parcels and hygiene kits "
                       "at PPS SJK(C) Dengkil. Available for all affected residents from 2pm to 6pm today.",
        "hazard_type": "aid",
        "alert_level": "advisory",
        "latitude": 2.8590,
        "longitude": 101.6780,
        "radius_km": 5.0,
        "source": "JKM Malaysia",
    },
    {
        "title": "INFRA: Road Closure Alert",
        "description": "The bridge connecting Dengkil to Salak Tinggi is currently closed to all vehicles "
                       "due to rising water levels. Please use alternative route via Cyberjaya.",
        "hazard_type": "infrastructure",
        "alert_level": "warning",
        "latitude": 2.8450,
        "longitude": 101.6950,
        "radius_km": 2.0,
        "source": "LLM Malaysia",
    },
    {
        "title": "Observe: Sg. Langat Water Level",
        "description": "Sungai Langat at Dengkil bridge has reached Warning Level (5.1m). "
                       "BOMBA monitoring team is on-site. Low-lying areas in Kg. Ampar Tenang "
                       "are advised to move valuables to higher ground.",
        "hazard_type": "flood",
        "alert_level": "observe",
        "latitude": 2.8620,
        "longitude": 101.6850,
        "radius_km": 4.0,
        "source": "DID Malaysia",
    },
    {
        "title": "Flood Alert: Kampung Sungai Besar",
        "description": "Rising water levels affecting Kampung Sungai Besar and surrounding low-lying "
                       "areas. Residents are advised to move valuables to higher ground and monitor "
                       "JPS updates. PPS Dewan Orang Ramai Sungai Besar is open for evacuees.",
        "hazard_type": "flood",
        "alert_level": "warning",
        "latitude": 3.6818,
        "longitude": 100.9930,
        "radius_km": 4.0,
        "source": "DID Malaysia",
    },
]


def main():
    print("Seeding warnings table...\n")
    for i, w in enumerate(SAMPLE_WARNINGS, 1):
        try:
            record = create_warning(**w)
            print(f"  [{i}/{len(SAMPLE_WARNINGS)}] [SUCCESS] Created: {record['title']}")
            print(f"       ID: {record['id']}")
            print(f"       Level: {record['alert_level']}  |  Hazard: {record['hazard_type']}")
            print(f"       Location: ({record['latitude']}, {record['longitude']})  r={record['radius_km']}km\n")
        except Exception as e:
            print(f"  [{i}/{len(SAMPLE_WARNINGS)}] [FAILED] Failed: {w['title']}")
            print(f"       Error: {e}\n")

    print("Done! Warnings seeded successfully.")
    print("Start the backend and the Flutter app to see them in action.")


if __name__ == "__main__":
    main()
