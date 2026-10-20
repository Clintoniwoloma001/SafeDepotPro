#!/usr/bin/env python3
"""
SafeDepot Pro - Supabase Data Migration Script
Reads LAFARGE_HSE_CUSTOMER_TRUCK_INSPECTION-3.xlsx and generates an idempotent
SQL migration that upserts depots, vehicles, inspectors/users, and truck inspections.

Run: python3 tools/import_lafarge_data.py
Output: supabase/migrations/0028_lafarge_data_import.sql

Key decisions:
  * depots: keyed on code (unique). allowed_radius_meters added additively.
  * trucks: keyed on reg_no = the plate TruckNumber. VehicleID (VEH-nnn) is
    preserved in source_meta->>'vehicle_id' so inspections can join on it,
    because the inspection log references VehicleID, not the plate.
  * truck_inspections: joined to trucks via source_meta vehicle_id.
"""
import os
import re
import sys
import json
import datetime

try:
    import openpyxl
except ImportError:
    print("ERROR: openpyxl is required. Install with: pip install openpyxl")
    sys.exit(1)

EXCEL_PATH = "/Users/clintoniwolomaimaginr/Downloads/LAFARGE_HSE_CUSTOMER_TRUCK_INSPECTION-3.xlsx"
OUTPUT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "supabase", "migrations", "0028_lafarge_data_import.sql"
)

ROLE_MAP = {
    "SUPER ADMIN": "SUPERADMIN",
    "SUPER_ADMIN": "SUPERADMIN",
    "C.HSE MANAGER": "COUNTRY_HEAD",
    "C_HSE_MANAGER": "COUNTRY_HEAD",
    "C.HSE_MANAGER": "COUNTRY_HEAD",
    "ADMIN": "ADMIN",
    "DSO": "USER",
    "USER": "USER",
}

DEPOT_CODE = {
    "AJAH": "AJAH", "AKURE": "AKURE", "IKORODU": "IKORODU", "EWEKORO": "EWEKORO",
    "IJEBU-ODE": "IJEBU-ODE", "ABA": "ABA", "ABEOKUTA": "ABEOKUTA",
    "ADO EKITI": "ADO-EKITI", "AGBARA": "AGBARA", "ENUGU": "ENUGU",
    "MONIYA": "MONIYA", "ONITSHA": "ONITSHA", "OREGUN": "OREGUN",
    "OSOGBO": "OSOGBO", "OWERRI": "OWERRI", "PORT HARCOURT": "PORT-HARCOURT",
    "UYO": "UYO", "ISEYIN": "ISEYIN", "ELEYELE": "ELEYELE", "COUNTRY": "COUNTRY",
}

CHECKLIST_ITEMS = [
    "MirrorGlass", "WindscreenWipers", "Steering", "BrakeLines",
    "TyresWheelNuts", "BrakesAirBuildUp", "Seatbelts", "LightsIndicators",
    "ProperFuelTank", "FuelLeaks", "BatteryCondition", "HornReverseAlarm",
    "UnderrunProtection", "Reflector", "SpareTireWheelSpanner", "Wedge",
    "FireExtinguisher",
]


def sql_str(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, (datetime.datetime, datetime.date)):
        return "'{}'".format(v.strftime("%Y-%m-%d"))
    s = str(v).strip()
    if not s:
        return "NULL"
    s = s.replace("'", "''")
    s = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", s)
    return "'{}'".format(s)


def sql_json(v):
    return "'{}'".format(json.dumps(v).replace("'", "''"))


def normalize_phone(v):
    """Excel stores phone numbers as floats; render them as clean digit strings."""
    if v is None:
        return None
    if isinstance(v, float):
        if v == int(v):
            return str(int(v))
        return str(v)
    if isinstance(v, int):
        return str(v)
    s = str(v).strip()
    if not s:
        return None
    if s.endswith(".0"):
        s = s[:-2]
    return s


def normalize_email(v):
    if not v:
        return None
    s = str(v).strip().lower()
    if "@" not in s:
        return None
    return s


def depot_code(name):
    if not name:
        return None
    key = str(name).strip().upper()
    return DEPOT_CODE.get(key, key.replace(" ", "-"))


def read_depots(wb):
    ws = wb["Depots"]
    depots = []
    seen = set()
    for row in ws.iter_rows(min_row=2, values_only=True):
        name = row[0]
        if not name or str(name).strip() in seen:
            continue
        name = str(name).strip()
        seen.add(name)

        def _f(x):
            try:
                return float(x) if x is not None else None
            except (TypeError, ValueError):
                return None

        radius = 50
        if row[3] is not None:
            try:
                radius = int(row[3])
            except (TypeError, ValueError):
                radius = 50
        depots.append({
            "code": depot_code(name), "name": name,
            "lat": _f(row[1]), "lng": _f(row[2]), "radius": radius,
        })
    return depots


def read_inspectors(wb):
    ws = wb["Inspectors"]
    inspectors = []
    seen = set()
    for row in ws.iter_rows(min_row=2, values_only=True):
        name, email, depot, role = row[1], normalize_email(row[2]), row[3], row[4]
        if not name or not email or email in seen:
            continue
        seen.add(email)
        inspectors.append({
            "name": str(name).strip(), "email": email,
            "depot": str(depot).strip() if depot else None,
            "role": ROLE_MAP.get(str(role).strip().upper() if role else "DSO", "USER"),
        })
    return inspectors


def read_users(wb):
    ws = wb["Users"]
    users = []
    seen = set()
    for row in ws.iter_rows(min_row=2, values_only=True):
        email, role, region, depot = normalize_email(row[0]), row[1], row[2], row[3]
        if not email or email in seen:
            continue
        seen.add(email)
        users.append({
            "email": email,
            "role": ROLE_MAP.get(str(role).strip().upper() if role else "USER", "USER"),
            "region": str(region).strip() if region else None,
            "depot": str(depot).strip() if depot else None,
        })
    return users


def read_notifications(wb):
    ws = wb["Notifications"]
    notifications = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        email = normalize_email(row[2])
        notify = row[3]
        if not email:
            continue
        notifications.append({
            "email": email,
            "notify_on_fail": bool(notify) if notify is not None else True,
        })
    return notifications


def read_vehicles(wb):
    ws = wb["Vehicles"]
    vehicles = []
    seen = set()
    for row in ws.iter_rows(min_row=2, values_only=True):
        vid = row[0]
        if not vid:
            continue
        vid = str(vid).strip()
        if vid in seen:
            continue
        seen.add(vid)
        ttype = str(row[3]).strip() if row[3] else None
        capacity = None
        if ttype:
            m = re.search(r"(\d+)", ttype)
            if m:
                capacity = int(m.group(1))
        vehicles.append({
            "vehicle_id": vid,
            "company": str(row[1]).strip() if row[1] else None,
            "truck_number": (str(row[2]).strip() if row[2] else vid),
            "truck_type": ttype,
            "capacity": capacity,
            "driver_name": str(row[4]).strip() if row[4] else None,
            "phone_number": normalize_phone(row[5]),
            "added_by": normalize_email(row[6]),
            "depot_name": str(row[7]).strip() if row[7] else None,
        })
    return vehicles


def read_inspections(wb):
    ws = wb["Truck Inspections"]
    inspections = []
    seen = set()
    for row in ws.iter_rows(min_row=2, values_only=True):
        iid = row[0]
        if not iid:
            continue
        iid = str(iid).strip()
        if iid in seen:
            continue
        seen.add(iid)
        final = str(row[36]).strip() if row[36] else ""
        created = None
        if isinstance(row[2], (datetime.datetime, datetime.date)):
            created = row[2]
        inspections.append({
            "inspection_id": iid,
            "inspection_number": str(row[1]).strip() if row[1] else None,
            "created_at": created,
            "inspection_location": str(row[3]).strip() if row[3] else None,
            "inspector_email": normalize_email(row[4]),
            "inspector_name": str(row[5]).strip() if row[5] else None,
            "depot": str(row[6]).strip() if row[6] else None,
            "role": str(row[7]).strip() if row[7] else None,
            "truck_id": str(row[8]).strip() if row[8] else None,
            "truck_number": str(row[9]).strip() if row[9] else None,
            "company": str(row[10]).strip() if row[10] else None,
            "driver_name": str(row[11]).strip() if row[11] else None,
            "driver_signature": str(row[12]).strip() if row[12] else None,
            "checklist": row[13:30],
            "truck_picture": str(row[30]).strip() if row[30] else None,
            "failure_photos": str(row[31]).strip() if row[31] else None,
            "remark": str(row[32]).strip() if row[32] else None,
            "next_inspection_due": row[33],
            "exemption_granted": row[34],
            "exemption_reason": str(row[35]).strip() if row[35] else None,
            "final_decision": final,
            "exempted_by": str(row[37]).strip() if row[37] else None,
        })
    return inspections


def read_excel():
    wb = openpyxl.load_workbook(EXCEL_PATH, data_only=True, read_only=True)
    return {
        "depots": read_depots(wb),
        "vehicles": read_vehicles(wb),
        "inspectors": read_inspectors(wb),
        "users": read_users(wb),
        "notifications": read_notifications(wb),
        "inspections": read_inspections(wb),
    }


def gen_header():
    return [
        "-- (c) Flatra Tech Ltd. All rights reserved.",
        "-- Designed and developed by Clinton Iwoloma -- The Imaginr, CEO, Flatra Tech Ltd.",
        "-- 0028_lafarge_data_import.sql -- upsert of the Excel export into Supabase.",
        "-- Idempotent: safe to re-run. Additive columns only; nothing dropped.",
        "",
        "begin;",
        "",
        "-- Additive geofence column (no existing column is altered).",
        "alter table public.depots",
        "  add column if not exists allowed_radius_meters int not null default 50;",
        "",
        "-- Additive source_meta on truck_inspections, holding the Excel row verbatim",
        "-- (inspector, company, GPS location, signature/photo paths, exemptions).",
        "alter table public.truck_inspections",
        "  add column if not exists source_meta jsonb not null default '{}'::jsonb;",
        "",
    ]


def gen_depots_sql(depots):
    lines = ["-- ===== 1. DEPOTS (geofence coordinates) =====",
             "insert into public.depots (code, name, city, region, latitude, longitude, allowed_radius_meters, is_active)",
             "values"]
    vals = []
    for d in depots:
        vals.append("  ({code}, {name}, {name}, 'SOUTH', {lat}, {lng}, {radius}, true)".format(
            code=sql_str(d["code"]), name=sql_str(d["name"]),
            lat=sql_str(d["lat"]), lng=sql_str(d["lng"]), radius=sql_str(d["radius"]),
        ))
    lines.append(",\n".join(vals))
    lines.append("on conflict (code) do update set")
    lines.append("  name = excluded.name,")
    lines.append("  latitude = excluded.latitude,")
    lines.append("  longitude = excluded.longitude,")
    lines.append("  allowed_radius_meters = excluded.allowed_radius_meters,")
    lines.append("  updated_at = now();")
    lines.append("")
    return lines


def gen_people_sql(users, inspectors):
    lines = ["-- ===== 2. PROFILES (auth users, roles, depot assignment) =====",
             "-- Auth users must already exist in auth.users. Create them in the",
             "-- Supabase dashboard first if a statement affects 0 rows."]
    all_people = {}
    for u in users:
        all_people[u["email"]] = {"email": u["email"], "name": None, "role": u["role"], "depot": u["depot"]}
    for i in inspectors:
        if i["email"] in all_people:
            all_people[i["email"]]["name"] = all_people[i["email"]]["name"] or i["name"]
            all_people[i["email"]]["depot"] = all_people[i["email"]]["depot"] or i["depot"]
        else:
            all_people[i["email"]] = {"email": i["email"], "name": i["name"], "role": i["role"], "depot": i["depot"]}
    for email in sorted(all_people.keys()):
        p = all_people[email]
        dcode = depot_code(p["depot"]) if p["depot"] else None
        lines.append("")
        lines.append("insert into public.profiles (id, full_name, role, depot_id)")
        lines.append("select au.id, {name}, {role}::public.user_role, {depot}".format(
            name=sql_str(p["name"] or email.split("@")[0].title()),
            role=sql_str(p["role"]),
            depot="d.id" if dcode else "NULL",
        ))
        lines.append("from auth.users au")
        if dcode:
            lines.append("left join public.depots d on d.code = {}".format(sql_str(dcode)))
        lines.append("where au.email = {}".format(sql_str(email)))
        lines.append("on conflict (id) do update set")
        lines.append("  full_name = excluded.full_name,")
        lines.append("  role = excluded.role,")
        if dcode:
            lines.append("  depot_id = coalesce(excluded.depot_id, profiles.depot_id),")
        lines.append("  updated_at = now();")
    lines.append("")
    return lines


def gen_vehicles_sql(vehicles):
    lines = ["-- ===== 3. VEHICLES -> trucks =====",
             "-- Trucks are unique on reg_no (the plate TruckNumber). VehicleID is",
             "-- preserved in source_meta->>'vehicle_id' because the inspection log",
             "-- references VehicleID rather than the plate number.",
             "",
             "insert into public.trucks (depot_id, reg_no, company, driver_name, driver_phone,",
             "  capacity_tonnes, status, is_active, source_meta)",
             "select d.id, t.reg_no, t.company, t.driver_name, t.driver_phone,",
             "  t.capacity_tonnes, 'OPERATIONAL', true, t.source_meta::jsonb",
             "from (values"]
    by_depot = {}
    for v in vehicles:
        key = depot_code(v["depot_name"]) if v["depot_name"] else None
        by_depot.setdefault(key, []).append(v)
    vals = []
    for dcode in sorted(by_depot.keys(), key=lambda x: x or ""):
        for v in by_depot[dcode]:
            meta = {
                "vehicle_id": v["vehicle_id"],
                "truck_type": v["truck_type"],
                "added_by": v["added_by"],
            }
            vals.append("  ({reg_no}, {company}, {driver}, {phone}, {cap}, {dcode}, {meta})".format(
                reg_no=sql_str(v["truck_number"]),
                company=sql_str(v["company"]),
                driver=sql_str(v["driver_name"]),
                phone=sql_str(v["phone_number"]),
                cap=sql_str(v["capacity"]),
                dcode=sql_str(dcode),
                meta=sql_json(meta),
            ))
    lines.append(",\n".join(vals))
    lines.append(") as t(reg_no, company, driver_name, driver_phone, capacity_tonnes, depot_code, source_meta)")
    lines.append("left join public.depots d on d.code = t.depot_code")
    lines.append("on conflict (reg_no) do update set")
    lines.append("  depot_id = coalesce(excluded.depot_id, trucks.depot_id),")
    lines.append("  company = coalesce(excluded.company, trucks.company),")
    lines.append("  driver_name = coalesce(excluded.driver_name, trucks.driver_name),")
    lines.append("  driver_phone = coalesce(excluded.driver_phone, trucks.driver_phone),")
    lines.append("  capacity_tonnes = coalesce(excluded.capacity_tonnes, trucks.capacity_tonnes),")
    lines.append("  source_meta = trucks.source_meta || excluded.source_meta,")
    lines.append("  updated_at = now();")
    lines.append("")
    return lines


def gen_inspections_sql(inspections):
    lines = ["-- ===== 4. TRUCK INSPECTIONS (1,619 historical logs) =====",
             "-- Joined to trucks through source_meta->>'vehicle_id' because the",
             "-- inspection log records VehicleID, not the plate. 'Pass' -> PASS."]
    batch = 100
    for start in range(0, len(inspections), batch):
        chunk = inspections[start:start + batch]
        lines.append("")
        lines.append("insert into public.truck_inspections (")
        lines.append("  truck_id, depot_id, checklist_name, result, compliance,")
        lines.append("  answers, driver_name, remarks, photographed_issues,")
        lines.append("  status, source_meta, created_at, updated_at")
        lines.append(")")
        lines.append("select t.id, d.id, 'Customer Truck Inspection',")
        lines.append("  case when v.result = 'PASS' then 'PASS'::public.truck_result")
        lines.append("       else 'FAIL'::public.truck_result end,")
        lines.append("  case when v.result = 'PASS' then 100.0 else 50.0 end,")
        lines.append("  v.answers::jsonb, v.driver_name, v.remarks, v.photo_paths,")
        lines.append("  'SUBMITTED'::public.inspection_status, v.source_meta::jsonb,")
        lines.append("  v.created_at, v.created_at")
        lines.append("from (values")
        vals = []
        for insp in chunk:
            result = "PASS" if (insp["final_decision"] or "").lower() == "pass" else "FAIL"
            created = insp["created_at"].strftime("%Y-%m-%d") if insp["created_at"] else "1970-01-01"
            answers = [{"item": name, "response": "PASS" if (insp["checklist"][idx] is True) else "FAIL"}
                       for idx, name in enumerate(CHECKLIST_ITEMS)]
            meta = {
                "inspection_id": insp["inspection_id"],
                "inspection_number": insp["inspection_number"],
                "inspector_email": insp["inspector_email"],
                "inspector_name": insp["inspector_name"],
                "truck_number": insp["truck_number"],
                "company": insp["company"],
                "inspection_location": insp["inspection_location"],
                "driver_signature": insp["driver_signature"],
                "truck_picture": insp["truck_picture"],
                "final_decision": insp["final_decision"],
                "exemption_granted": insp["exemption_granted"],
                "exemption_reason": insp["exemption_reason"],
                "exempted_by": insp["exempted_by"],
                "next_inspection_due": (
                    insp["next_inspection_due"].strftime("%Y-%m-%d")
                    if isinstance(insp["next_inspection_due"], (datetime.datetime, datetime.date))
                    else None
                ),
            }
            vals.append("  ({veh}, {depot}, {result}, {driver}, {remarks}, {photos}, {created}, {answers}, {meta})".format(
                veh=sql_str(insp["truck_id"] or insp["truck_number"]),
                depot=sql_str(depot_code(insp["depot"]) if insp["depot"] else None),
                result=sql_str(result),
                driver=sql_str(insp["driver_name"]),
                remarks=sql_str(insp["remark"]),
                photos="'{}'::text[]",
                created=sql_str(created),
                answers=sql_json(answers),
                meta=sql_json(meta),
            ))
        lines.append(",\n".join(vals))
        lines.append(") as v(vehicle_id, depot_code, result, driver_name, remarks, photo_paths, created_at, answers, source_meta)")
        lines.append("join public.trucks t on t.source_meta->>'vehicle_id' = v.vehicle_id")
        lines.append("left join public.depots d on d.code = v.depot_code")
        lines.append("on conflict do nothing;")
    lines.append("")
    return lines


def generate_sql(data):
    lines = gen_header()
    lines += gen_depots_sql(data["depots"])
    lines += gen_people_sql(data["users"], data["inspectors"])
    lines += gen_vehicles_sql(data["vehicles"])
    lines += gen_inspections_sql(data["inspections"])
    lines.append("commit;")
    lines.append("")
    lines.append("-- ===== END =====")
    return "\n".join(lines)


def main():
    if not os.path.exists(EXCEL_PATH):
        print("ERROR: Excel file not found at {}".format(EXCEL_PATH))
        sys.exit(1)
    print("Reading Excel file...")
    data = read_excel()
    print("  depots:      {}".format(len(data["depots"])))
    print("  vehicles:    {}".format(len(data["vehicles"])))
    print("  inspectors:  {}".format(len(data["inspectors"])))
    print("  users:       {}".format(len(data["users"])))
    print("  inspections: {}".format(len(data["inspections"])))
    print("Generating SQL migration...")
    sql = generate_sql(data)
    with open(OUTPUT_PATH, "w") as f:
        f.write(sql)
    print("Wrote {} ({} bytes)".format(OUTPUT_PATH, len(sql)))
    print("Done.")


if __name__ == "__main__":
    main()
