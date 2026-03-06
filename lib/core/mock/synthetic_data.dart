class SyntheticData {
  static const List<Map<String, dynamic>> plants =[
    {"id": "p1", "name": "Goa Shipyard Limited", "capacityKw": 50.45, "status": "ACTIVE", "todayKwh": 62, "devices": 55},
    {"id": "p2", "name": "Dehgam Plant", "capacityKw": 120.0, "status": "ACTIVE", "todayKwh": 4567, "devices": 102},
  ];

  static const List<Map<String, dynamic>> inverters =[
    {"id": "inv1", "plantId": "p1", "name": "GRP_INVERTER_7", "todayKwh": 76356, "totalKwh": 42567890, "status": "ACTIVE"},
    {"id": "inv2", "plantId": "p1", "name": "SPS_INVERTER_13", "todayKwh": 76356, "totalKwh": 42567890, "status": "ACTIVE"},
  ];

  static const List<Map<String, dynamic>> slmsDevices =[
    {"id": "slms1", "name": "Kutch Plant String 1", "ctCount": 5, "totalCurrent": 43.12, "lastUpdated": "Jan 10, 8:00 AM"},
    {"id": "slms2", "name": "Kutch Plant String 2", "ctCount": 5, "totalCurrent": 41.05, "lastUpdated": "Jan 10, 8:00 AM"},
  ];

  static const List<Map<String, dynamic>> alerts = [
    {"id": "a1", "name": "Grid Voltage High", "status": "ACTIVE", "plants": {"name": "Goa Shipyard Limited"}, "devices": {"name": "GRP_INVERTER_7"}, "created_at": "2026-03-06T08:00:00"},
    {"id": "a2", "name": "DC Bus Overvoltage", "status": "ACTIVE", "plants": {"name": "Dehgam Plant"}, "devices": {"name": "SPS_INVERTER_13"}, "created_at": "2026-03-05T14:30:00"},
    {"id": "a3", "name": "Inverter Overtemperature", "status": "WARNING", "plants": {"name": "Goa Shipyard Limited"}, "devices": {"name": "GRP_INVERTER_7"}, "created_at": "2026-03-05T10:15:00"},
    {"id": "a4", "name": "String Current Mismatch", "status": "WARNING", "plants": {"name": "Dehgam Plant"}, "devices": {"name": "SPS_INVERTER_13"}, "created_at": "2026-03-04T09:00:00"},
  ];
}