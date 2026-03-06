"""Seed the risk_zones, evacuation_centres, and evacuation_routes tables.

Run from the backend_fastapi directory:
    python -m scripts.seed_risk_map
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.risk_zones import (
    create_risk_zone,
    create_evacuation_centre,
    create_evacuation_route,
)


# ── Sample Risk Zones near Kuantan & Sepang ──────────────────────────────────

RISK_ZONES = [
    {
        "name": "Sungai Lembing Flood Zone",
        "zone_type": "danger",
        "hazard_type": "flood",
        "latitude": 3.9200,
        "longitude": 103.0200,
        "radius_km": 3.0,
        "risk_score": 0.92,
        "description": "Historical flood-prone area along Sungai Lembing.",
    },
    {
        "name": "Sungai Sepang Lowlands",
        "zone_type": "danger",
        "hazard_type": "flood",
        "latitude": 2.6850,
        "longitude": 101.7400,
        "radius_km": 2.5,
        "risk_score": 0.88,
        "description": "Riverbank area prone to tidal flooding and heavy monsoon rainfall.",
    },
    {
        "name": "Salak Tinggi Clay Slope",
        "zone_type": "warning",
        "hazard_type": "landslide",
        "latitude": 2.8210,
        "longitude": 101.7420,
        "radius_km": 1.2,
        "risk_score": 0.65,
        "description": "Hillside area in Salak Tinggi with potential for soil movement after rain.",
    },
    {
        "name": "Kota Warisan Drainage Point",
        "zone_type": "warning",
        "hazard_type": "flood",
        "latitude": 2.8230,
        "longitude": 101.7050,
        "radius_km": 1.8,
        "risk_score": 0.52,
        "description": "Localized flash flood risk during extreme downpours.",
    },
    {
        "name": "Dengkil Lowland Risk",
        "zone_type": "danger",
        "hazard_type": "flood",
        "latitude": 2.8550,
        "longitude": 101.6800,
        "radius_km": 2.2,
        "risk_score": 0.90,
        "description": "Area near Langat River prone to flash floods during high tide and rain.",
    },
    {
        "name": "Olak Lempit Industrial Hazard",
        "zone_type": "warning",
        "hazard_type": "flood",
        "latitude": 2.8350,
        "longitude": 101.5500,
        "radius_km": 1.5,
        "risk_score": 0.58,
        "description": "Industrial zone with potential drainage overflow.",
    },
    {
        "name": "Kuantan Riverbank Risk Area",
        "zone_type": "danger",
        "hazard_type": "flood",
        "latitude": 3.8100,
        "longitude": 103.3280,
        "radius_km": 2.5,
        "risk_score": 0.85,
        "description": "Low-lying area near Kuantan River.",
    },
]

# ── Sample Evacuation Centres (PPS) ──────────────────────────────────────────

EVACUATION_CENTRES = [
    {
        "name": "Dewan Komuniti Bukit Pelindung",
        "latitude": 3.8350,
        "longitude": 103.3450,
        "capacity": 500,
        "current_occupancy": 0,
        "contact_phone": "+60129876543",
        "address": "Jalan Bukit Pelindung, Kuantan, Pahang",
    },
    {
        "name": "PPS SJK(C) Dengkil",
        "latitude": 2.8590,
        "longitude": 101.6780,
        "capacity": 350,
        "current_occupancy": 0,
        "contact_phone": "+60387680001",
        "address": "Pekan Dengkil, 43800 Dengkil",
    },
    {
        "name": "Dewan Orang Ramai Dengkil",
        "latitude": 2.8620,
        "longitude": 101.6810,
        "capacity": 500,
        "current_occupancy": 0,
        "contact_phone": "+60387680002",
        "address": "Jalan Banting, Dengkil",
    },
    {
        "name": "Dewan Orang Ramai Olak Lempit",
        "latitude": 2.8310,
        "longitude": 101.5450,
        "capacity": 400,
        "current_occupancy": 0,
        "contact_phone": "+60331490001",
        "address": "Kampung Olak Lempit, Banting",
    },
    {
        "name": "SK Olak Lempit (Relief Centre)",
        "latitude": 2.8330,
        "longitude": 101.5480,
        "capacity": 300,
        "current_occupancy": 0,
        "contact_phone": "+60331490002",
        "address": "Jalan Besar Olak Lempit",
    },
    {
        "name": "Pusat Pemindahan PPS Sepang Town",
        "latitude": 2.6950,
        "longitude": 101.7510,
        "capacity": 400,
        "current_occupancy": 0,
        "contact_phone": "+60387061234",
        "address": "Jalan Besar, Sepang Town",
    },
    {
        "name": "Dewan Orang Ramai Salak Tinggi",
        "latitude": 2.8150,
        "longitude": 101.7370,
        "capacity": 600,
        "current_occupancy": 0,
        "contact_phone": "+60387065678",
        "address": "Taman BBST, Salak Tinggi, Sepang",
    },
    {
        "name": "SK Kota Warisan (Relief Centre)",
        "latitude": 2.8250,
        "longitude": 101.7020,
        "capacity": 450,
        "current_occupancy": 5,
        "contact_phone": "+60387069999",
        "address": "Bandar Baru Salak Tinggi, Sepang",
    },
    {
        "name": "Masjid Jamek Sultan Hisamuddin",
        "latitude": 2.8100,
        "longitude": 101.7320,
        "capacity": 300,
        "current_occupancy": 0,
        "contact_phone": "+60387060000",
        "address": "Jalan Masjid, Salak Tinggi",
    },
    {
        "name": "Dewan Serbaguna Cyberjaya",
        "latitude": 2.9230,
        "longitude": 101.6540,
        "capacity": 800,
        "current_occupancy": 0,
        "contact_phone": "+60383121111",
        "address": "Persiaran Multimedia, Cyberjaya",
    },
    {
        "name": "Masjid Raja Haji Fisabilillah",
        "latitude": 2.9180,
        "longitude": 101.6520,
        "capacity": 400,
        "current_occupancy": 0,
        "contact_phone": "+60383122222",
        "address": "Cyberjaya City Centre",
    },
    {
        "name": "SK Pandan Perdana (School Shelter)",
        "latitude": 3.8180,
        "longitude": 103.3350,
        "capacity": 300,
        "current_occupancy": 12,
        "contact_phone": "+60137654321",
        "address": "Jalan Pandan, Kuantan, Pahang",
    },
]

# ── Sample Evacuation Routes ──────────────────────────────────────────────

EVACUATION_ROUTES = [
    {
        "name": "Route A: Town -> Bukit Pelindung",
        "start_lat": 3.8077,
        "start_lon": 103.3260,
        "end_lat": 3.8350,
        "end_lon": 103.3450,
        "waypoints": [
            {"lat": 3.8100, "lon": 103.3300},
            {"lat": 3.8150, "lon": 103.3350},
        ],
        "distance_km": 4.2,
        "estimated_minutes": 15,
        "elevation_gain_m": 45.0,
        "status": "clear",
    },
    {
        "name": "Sepang: Town -> PPS Sepang",
        "start_lat": 2.6850,
        "start_lon": 101.7400,
        "end_lat": 2.6950,
        "end_lon": 101.7510,
        "waypoints": [
            {"lat": 2.6900, "lon": 101.7450},
        ],
        "distance_km": 1.5,
        "estimated_minutes": 8,
        "elevation_gain_m": 10.0,
        "status": "clear",
    },
    {
        "name": "Salak Tinggi: Slope -> BBST Hall",
        "start_lat": 2.8210,
        "start_lon": 101.7420,
        "end_lat": 2.8150,
        "end_lon": 101.7370,
        "waypoints": [
            {"lat": 2.8180, "lon": 101.7400},
        ],
        "distance_km": 1.2,
        "estimated_minutes": 6,
        "elevation_gain_m": 5.0,
        "status": "clear",
    },
]


def main():
    print("-" * 60)
    print("  Seeding AI Risk Map data")
    print("-" * 60)

    print("\n[ZONES] Risk Zones:")
    for i, z in enumerate(RISK_ZONES, 1):
        try:
            rec = create_risk_zone(**z)
            icon = {"danger": "[DANGER]", "warning": "[WARNING]", "safe": "[SAFE]"}[rec["zone_type"]]
            print(f"  {icon} [{i}] {rec['name']} ({rec['zone_type']}) - score: {rec['risk_score']}")
        except Exception as e:
            print(f"  [X] [{i}] Failed: {z['name']}: {e}")

    print("\n[CENTRES] Evacuation Centres:")
    for i, c in enumerate(EVACUATION_CENTRES, 1):
        try:
            rec = create_evacuation_centre(**c)
            print(f"  [HOME] [{i}] {rec['name']} - capacity: {rec['capacity']}")
        except Exception as e:
            print(f"  [X] [{i}] Failed: {c['name']}: {e}")

    print("\n[ROUTES] Evacuation Routes:")
    for i, r in enumerate(EVACUATION_ROUTES, 1):
        try:
            rec = create_evacuation_route(**r)
            print(f"  [>>>] [{i}] {rec['name']} - {rec['distance_km']}km, ~{rec['estimated_minutes']}min")
        except Exception as e:
            print(f"  [X] [{i}] Failed: {r['name']}: {e}")

    print("\n" + "-" * 60)
    print("  Done! Risk map data seeded successfully.")
    print("-" * 60)


if __name__ == "__main__":
    main()
