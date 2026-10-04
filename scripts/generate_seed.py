#!/usr/bin/env python3
"""
Generates supabase/seed.sql — the anonymised demonstration dataset for the
SBTF System (Municipality of Mabini, Batangas).

Why a generator?
  * The specification requires approximately 24 TODAs and 817 anonymised
    members with NO real personal information. Generating them from fixed
    name pools and a fixed random seed makes the dataset reproducible and
    auditable: anyone can re-run this script and obtain byte-identical output.
  * The demo accounts, applications, documents and franchise records are
    synthetic. No record in seed.sql corresponds to a real person.

Usage:
    python3 scripts/generate_seed.py > supabase/seed.sql
"""

from __future__ import annotations

import random
from datetime import date, datetime, timedelta, timezone

random.seed(20260101)

# --------------------------------------------------------------------------
# Reference data
# --------------------------------------------------------------------------

# 24 accredited TODAs based on Mabini, Batangas communities (PSA barangay codes).
TODAS: list[tuple[str, str, str, int]] = [
    # (code, name, barangay_code, member_count) — member counts sum to exactly 817
    ("TODA-001", "TODA Anilao Proper", "041016001", 63),
    ("TODA-002", "TODA Anilao East", "041016002", 57),
    ("TODA-003", "TODA Bagalangit", "041016003", 54),
    ("TODA-004", "TODA Bulacan", "041016004", 50),
    ("TODA-005", "TODA Calamias", "041016005", 46),
    ("TODA-006", "TODA Estrella", "041016006", 43),
    ("TODA-007", "TODA Gasang", "041016007", 41),
    ("TODA-008", "TODA Laurel", "041016008", 39),
    ("TODA-009", "TODA Ligaya", "041016009", 37),
    ("TODA-010", "TODA Mainaga", "041016010", 35),
    ("TODA-011", "TODA Mainit", "041016011", 33),
    ("TODA-012", "TODA Majuben", "041016012", 31),
    ("TODA-013", "TODA Malimatoc", "041016013", 30),
    ("TODA-014", "TODA Nag-iba", "041016015", 28),
    ("TODA-015", "TODA Pilahan", "041016016", 28),
    ("TODA-016", "TODA Poblacion", "041016017", 26),
    ("TODA-017", "TODA Pulang Lupa", "041016018", 26),
    ("TODA-018", "TODA Pulong Anahao", "041016019", 24),
    ("TODA-019", "TODA Pulong Niogan", "041016021", 24),
    ("TODA-020", "TODA Saguing", "041016022", 22),
    ("TODA-021", "TODA Sampaguita", "041016023", 22),
    ("TODA-022", "TODA San Francisco", "041016024", 20),
    ("TODA-023", "TODA San Teodoro", "041016027", 20),
    ("TODA-024", "TODA Talaga", "041016034", 18),
]

# Fixed pools of fictional names — no correspondence to real individuals.
FIRST_NAMES = [
    "Adrian", "Alvin", "Andrea", "Angelo", "Antonio", "Arnel", "Benjamin", "Bernardo",
    "Carlito", "Cesar", "Christian", "Danilo", "Dante", "Dennis", "Dominador", "Edgar",
    "Edmund", "Efren", "Elmer", "Emmanuel", "Ernesto", "Eduardo", "Ferdinand", "Fernando",
    "Fidel", "Francisco", "Gabriel", "Gerardo", "Gilbert", "Gregorio", "Henry", "Ignacio",
    "Isagani", "Jaime", "Jason", "Joel", "Jonathan", "Jose", "Joseph", "Juan",
    "Julio", "Leandro", "Leonardo", "Lorenzo", "Manuel", "Marcelo", "Mario", "Marvin",
    "Melchor", "Michael", "Miguel", "Nestor", "Noel", "Oliver", "Orlando", "Oscar",
    "Pablo", "Pedro", "Rafael", "Ramil", "Ramon", "Raul", "Renato", "Ricardo",
    "Roberto", "Rodolfo", "Rogelio", "Rolando", "Romeo", "Ronald", "Rowel", "Ruben",
    "Salvador", "Samuel", "Santiago", "Teodoro", "Vincent", "Virgilio", "Wilfredo", "Wilson",
]

MIDDLE_NAMES = [
    "Abad", "Aguilar", "Alcantara", "Alvarez", "Angeles", "Aquino", "Bautista", "Bernardo",
    "Cabrera", "Castro", "Cortez", "Cruz", "Dela Cruz", "Diaz", "Domingo", "Enriquez",
    "Espino", "Estrada", "Fernandez", "Flores", "Francisco", "Garcia", "Gonzales", "Hernandez",
    "Ilagan", "Jimenez", "Lopez", "Magsaysay", "Mangubat", "Manalo", "Marasigan", "Mendoza",
    "Mercado", "Navarro", "Ocampo", "Ortiz", "Padilla", "Panganiban", "Pascual", "Perez",
    "Quizon", "Ramos", "Reyes", "Rivera", "Rodriguez", "Rosales", "Salazar", "Santiago",
    "Santos", "Silang", "Tolentino", "Torres", "Valdez", "Villanueva", "Ylagan", "Zamora",
]

LAST_NAMES = [
    "Abanto", "Agbayani", "Almario", "Ambid", "Aniag", "Aparente", "Atienza", "Bagui",
    "Balbuena", "Banaag", "Bautista", "Bilog", "Briones", "Buenaventura", "Cabrera",
    "Cantos", "Casapao", "Catibog", "Claveria", "Contreras", "Cueto", "Dalisay",
    "De Guzman", "De Villa", "Dimaculangan", "Dimaano", "Ebora", "Escalante", "Fajardo",
    "Feliciano", "Garcia", "Gatbonton", "Gonzales", "Guevarra", "Hernandez", "Ilagan",
    "Javier", "Landicho", "Lat", "Lipa", "Macatangay", "Magbuhos", "Malabanan",
    "Mancenido", "Maralit", "Mendoza", "Mercado", "Miranda", "Mojica", "Montales",
    "Naval", "Nolasco", "Ocampo", "Olivares", "Olaes", "Ortega", "Panganiban", "Pastor",
    "Peña", "Perez", "Quinto", "Ramos", "Ramoso", "Rico", "Rivera", "Rosales",
    "Saguin", "Salazar", "Sandoval", "Sarmiento", "Silang", "Sison", "Tenorio",
    "Tolentino", "Umali", "Valencia", "Vasquez", "Villamor", "Yabut", "Zamora",
]

VEHICLE_MAKES_MODELS = [
    ("Honda", "TMX 155"), ("Kawasaki", "Barako 175"), ("Yamaha", "YBR 125"),
    ("Suzuki", "GD 110"), ("Kawasaki", "CT100"), ("Honda", "Wave 125"),
    ("Rusi", "Classic 250"), ("Motorstar", "Z200"), ("Kawasaki", "Curve 110"),
    ("Honda", "XRM 125"),
]

VEHICLE_COLORS = [
    "Blue", "Red", "Black", "White", "Silver", "Green", "Yellow", "Maroon",
    "Orange", "Gray",
]

REJECTION_REASONS = [
    "Barangay clearance presented has already expired; please submit a clearance issued within the current year.",
    "Photocopy of the Certificate of Registration is not legible; a clear copy or scanned original is required.",
    "Registered vehicle owner differs from the declared operator; please submit a deed of sale or authority to operate.",
    "Cedula presented belongs to a different individual; please upload the operator's own cedula.",
    "Chassis number declared in the application does not match the OR/CR on file; please verify and re-submit.",
    "Membership certificate from the TODA does not indicate active membership for the current year.",
]


def esc(value: str) -> str:
    return value.replace("'", "''")


def pseudo_email(index: int, role: str) -> str:
    return f"{role}{index:03d}@mabini-sbtf.test"


# --------------------------------------------------------------------------
# Demo accounts
# --------------------------------------------------------------------------

lines: list[str] = []
w = lines.append

w("-- " + "=" * 75)
w("-- SBTF System — demonstration / development dataset (ANONYMISED)")
w("-- Municipality of Mabini, Batangas — Franchising and Tricycle Driver")
w("-- Registration System")
w("--")
w("-- !!! DEVELOPMENT ONLY !!!")
w("-- This file creates synthetic accounts and records. It contains no real")
w("-- personal information. Do NOT run it against the production project.")
w("--")
w("-- Applied automatically by:  supabase db reset")
w("-- Applied manually by    :  psql \"$DATABASE_URL\" -f supabase/seed.sql")
w("--")
w("-- Generated by scripts/generate_seed.py — edit the generator, not the output.")
w("-- " + "=" * 75)
w("")
w("begin;")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- 0. Helper used to create Supabase Auth accounts with confirmed e-mail")
w("--    addresses. Cryptography stays inside Supabase Auth (pgcrypto crypt()/")
w("--    gen_salt()); the application never stores password material.")
w("-- ---------------------------------------------------------------------------")
w("""create or replace function public.seed_create_auth_user(
  p_email      text,
  p_password   text,
  p_role       public.user_role,
  p_first_name text,
  p_middle_name text,
  p_last_name  text,
  p_contact    text,
  p_barangay   text,
  p_address    text,
  p_created_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  if exists (select 1 from public.profiles where lower(email) = lower(p_email)) then
    select id into v_id from public.profiles where lower(email) = lower(p_email);
    return v_id;
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
    lower(p_email), crypt(p_password, gen_salt('bf')), p_created_at,
    jsonb_build_object('provider', 'email', 'providers', array['email'], 'role', p_role),
    jsonb_build_object(
      'first_name', p_first_name, 'middle_name', p_middle_name, 'last_name', p_last_name,
      'contact_number', p_contact, 'address_line', p_address, 'barangay_code', p_barangay
    ),
    p_created_at, p_created_at, '', '', '', ''
  );

  if exists (
    select 1 from information_schema.columns
     where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
  ) then
    execute $sql$
      insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), $1, $2, jsonb_build_object('sub', $2, 'email', $3, 'email_verified', true), 'email', now(), now(), now())
    $sql$ using v_id, v_id::text, lower(p_email);
  else
    execute $sql$
      insert into auth.identities (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), $1, jsonb_build_object('sub', $1::text, 'email', $2, 'email_verified', true), 'email', now(), now(), now())
    $sql$ using v_id, lower(p_email);
  end if;

  -- The auth trigger has already created the profile row; complete it.
  update public.profiles
     set role = p_role,
         first_name = p_first_name,
         middle_name = nullif(btrim(coalesce(p_middle_name, '')), ''),
         last_name = p_last_name,
         contact_number = p_contact,
         address_line = p_address,
         barangay_code = p_barangay,
         account_status = 'active',
         created_at = p_created_at
   where id = v_id;

  return v_id;
end;
$$;""")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- 1. TODAs (24 accredited associations)")
w("-- ---------------------------------------------------------------------------")
w("insert into public.todas (code, name, barangay_code, zone) values")
toda_values = []
for idx, (code, name, brgy, _members) in enumerate(TODAS):
    zone = f"Zone {(idx % 6) + 1}"
    toda_values.append(f"  ('{code}', '{esc(name)}', '{brgy}', '{zone}')")
w(",\n".join(toda_values))
w("on conflict (code) do nothing;")
w("")
w("-- ---------------------------------------------------------------------------")
total_members = sum(t[3] for t in TODAS)
assert total_members == 817, f"member counts must sum to 817, got {total_members}"
w(f"-- 2. TODA membership masterlist — {total_members} anonymised members")
w("--    No names, addresses or contact details: membership statistics only.")
w("-- ---------------------------------------------------------------------------")
w("with counts as (")
w("  select * from (values")
count_values = ",\n".join(
    f"    ('{code}', {members})" for code, _n, _b, members in TODAS
)
w(count_values)
w("  ) as t(code, member_count)")
w(")")
w("insert into public.toda_members (toda_id, member_ref, display_name, year_joined, is_active)")
w("select t.id,")
w("       t.code || '-M' || lpad(gs.n::text, 4, '0'),")
w("       'Member ' || lpad(gs.n::text, 4, '0'),")
w("       -- Deterministic spread of join years between 1998 and 2025")
w("       (1998 + ((gs.n * 7 + length(t.code)) % 28))::smallint,")
w("       (gs.n % 17 <> 0)  -- roughly 6% inactive roster entries")
w("  from counts c")
w("  join public.todas t on t.code = c.code")
w("  cross join lateral generate_series(1, c.member_count) as gs(n)")
w("on conflict (member_ref) do nothing;")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- 3. Demonstration accounts")
w("--    administrator : 1 account")
w("--    staff         : 3 accounts")
w("--    driver        : 72 accounts (three per TODA, linked to the roster)")
w("--    Passwords are demonstration values and must be changed in any real")
w("--    deployment (they are documented in docs/deployment.md).")
w("-- ---------------------------------------------------------------------------")
w("do $$")
w("declare")
w("  v_id uuid;")
w("  r    record;")
w("begin")
w("  perform public.seed_create_auth_user(")
w("    'admin@mabini-sbtf.test', 'Admin@Mabini2026', 'administrator',")
w("    'Apolinaria', 'Reyes', 'Domingo', '09171234501', '041016017',")
w("    'Municipal Hall, Poblacion, Mabini, Batangas', now() - interval '400 days');")
w("")
w("  perform public.seed_create_auth_user(")
w("    'staff1@mabini-sbtf.test', 'Staff@Mabini2026', 'staff',")
w("    'Benigno', 'Cruz', 'Magsaysay', '09171234502', '041016017',")
w("    'Sangguniang Bayan Office, Poblacion, Mabini, Batangas', now() - interval '380 days');")
w("")
w("  perform public.seed_create_auth_user(")
w("    'staff2@mabini-sbtf.test', 'Staff@Mabini2026', 'staff',")
w("    'Corazon', 'Lim', 'Villamor', '09171234503', '041016017',")
w("    'Sangguniang Bayan Office, Poblacion, Mabini, Batangas', now() - interval '300 days');")
w("")
w("  perform public.seed_create_auth_user(")
w("    'staff3@mabini-sbtf.test', 'Staff@Mabini2026', 'staff',")
w("    'Diosdado', 'Ybañez', 'Panganiban', '09171234504', '041016009',")
w("    'Sangguniang Bayan Office, Poblacion, Mabini, Batangas', now() - interval '120 days');")
w("")
w("  -- Driver accounts: two to three per TODA so every dashboard segment has data.")
w("  for r in")
w("    select t.code, t.barangay_code, row_number() over (order by t.code) as toda_rank")
w("      from public.todas t")
w("  loop")
w("    for i in 1..3 loop")
w("      v_id := public.seed_create_auth_user(")
w("        'driver' || lpad((r.toda_rank * 10 + i)::text, 3, '0') || '@mabini-sbtf.test',")
w("        'Driver@Mabini2026', 'driver',")
w("        (array['Adrian','Alvin','Arnel','Benjamin','Carlito','Danilo','Dennis','Edgar','Efren','Elmer','Ernesto','Ferdinand','Gilbert','Gregorio','Henry','Isagani','Jaime','Joel','Jonathan','Jose','Julio','Leonardo','Lorenzo','Manuel','Marcelo','Mario','Marvin','Melchor','Michael','Nestor','Noel','Oliver','Orlando','Oscar','Pablo','Pedro','Rafael','Ramil','Ramon','Raul','Renato','Ricardo','Roberto','Rodolfo','Rogelio','Rolando','Romeo','Ronald','Ruben','Salvador','Samuel','Teodoro','Vincent','Virgilio','Wilfredo','Wilson','Antonio','Cesar','Dominador','Emmanuel'])[(r.toda_rank * 3 + i) % 60 + 1],")
w("        (array['Abad','Aguilar','Alcantara','Alvarez','Angeles','Aquino','Bautista','Bernardo','Cabrera','Castro','Cortez','Cruz','Diaz','Domingo','Enriquez','Espino','Estrada','Fernandez','Flores','Francisco','Garcia','Gonzales','Hernandez','Jimenez','Lopez','Mendoza','Mercado','Navarro','Ocampo','Ortiz','Padilla','Pascual','Perez','Ramos','Reyes','Rivera','Rodriguez','Rosales','Salazar','Santiago','Santos','Tolentino','Torres','Valdez','Villanueva','Zamora','Marasigan','Manalo','Malabanan','Macatangay'])[(r.toda_rank * 3 + i) % 50 + 1],")
w("        (array['Abanto','Agbayani','Almario','Atienza','Balbuena','Banaag','Bautista','Briones','Buenaventura','Cabrera','Cantos','Claveria','Contreras','Dalisay','De Guzman','Dimaculangan','Dimaano','Ebora','Fajardo','Feliciano','Garcia','Gonzales','Guevarra','Hernandez','Javier','Landicho','Lipa','Malabanan','Mendoza','Miranda','Nolasco','Ocampo','Olivares','Ortega','Panganiban','Pastor','Perez','Quinto','Ramos','Ramoso','Rico','Rivera','Salazar','Sandoval','Sarmiento','Silang','Sison','Tenorio','Tolentino','Umali','Valencia','Vasquez','Villamor','Yabut','Zamora'])[(r.toda_rank * 3 + i) % 55 + 1],")
w("        '0918' || lpad(((r.toda_rank * 37 + i * 7) % 10000000)::text, 7, '0'),")
w("        r.barangay_code,")
w("        'Purok ' || (1 + (r.toda_rank % 5)) || ', ' || r.code,")
w("        now() - ((r.toda_rank * 3 + i) * 7 + 20) * interval '1 day');")
w("    end loop;")
w("  end loop;")
w("")
w("  -- Link roster entries to the registered accounts of their TODA.")
w("  with ranked as (")
w("    select m.id,")
w("           row_number() over (partition by m.toda_id order by m.member_ref) as rn")
w("      from public.toda_members m")
w("  )")
w("  update public.toda_members m")
w("     set profile_id = d.id")
w("    from ranked r")
w("    join public.profiles d")
w("      on d.role = 'driver'")
w("     and d.toda_id = (select toda_id from public.toda_members where id = r.id)")
w("     and d.email like 'driver%'")
w("   where m.id = r.id and r.rn <= 3;")
w("end")
w("$$;")
w("")


# --------------------------------------------------------------------------
# Applications / documents / records
# --------------------------------------------------------------------------
# Design notes for the generated dataset
#   * Every driver account owns one fictional tricycle, so a renewal application
#     carries exactly the same plate and vehicle data as the franchise it
#     replaces — as it would in the municipal office.
#   * A renewal always points at the franchise record created for that driver's
#     earlier approved application, and the predecessor record is then stamped
#     with renewed_by_record_id. The chain is therefore verifiable in both
#     directions, which is what the analytics and the renewal reminders rely on.
#   * At most one pending application exists per driver, and at most one pending
#     renewal per predecessor record, so the partial unique indexes hold.

driver_slots: list[dict] = []
for r_idx, (code, _name, brgy, _m) in enumerate(TODAS):
    for i in range(1, 4):
        slot_index = r_idx * 3 + i
        make, model = VEHICLE_MAKES_MODELS[slot_index % len(VEHICLE_MAKES_MODELS)]
        driver_slots.append(
            {
                "email": pseudo_email((r_idx + 1) * 10 + i, "driver"),
                "toda": code,
                "barangay": brgy,
                "plate": f"TRI {1000 + slot_index * 7}",
                "make": make,
                "model": model,
                "year": 2005 + (slot_index % 19),
                "color": VEHICLE_COLORS[slot_index % len(VEHICLE_COLORS)],
                "engine": f"ENG{slot_index * 131:08d}",
                "chassis": f"CHS{slot_index * 197:08d}",
                "capacity": 4 + (slot_index % 3),
            }
        )

today = date(2026, 1, 5)  # fixed reference date keeps the dataset reproducible

# Seasonal weighting: the renewal season (Jan-Mar) and mid-year (Aug) are busier.
SEASONAL_MONTHS = [1, 1, 1, 2, 2, 3, 3, 4, 5, 6, 7, 8, 8, 9, 10, 11, 11, 12]

apps = []
pending_drivers: set[str] = set()
pending_predecessors: set[int] = set()
approved_by_driver: dict[str, list[int]] = {}

for i in range(180):
    month = SEASONAL_MONTHS[(i * 5) % len(SEASONAL_MONTHS)]
    year = 2024 if (i % 7 == 0 and month <= 6) else 2025
    day = 1 + ((i * 13) % 27)
    submitted = date(year, month, day)
    if submitted > today - timedelta(days=3):
        submitted = today - timedelta(days=20 + (i % 60))

    age_days = (today - submitted).days
    if age_days <= 30 or i % 6 == 0:
        # Recently filed applications plus a standing queue for the demonstration.
        status = "pending"
    elif i % 9 == 4:
        status = "rejected"
    else:
        status = "approved"

    # Pick a driver: a driver may hold at most one open application at a time
    # (partial unique index applications_one_open_per_applicant).
    attempt = 0
    while True:
        slot = driver_slots[(i * 7 + attempt) % len(driver_slots)]
        if status != "pending" or slot["email"] not in pending_drivers:
            break
        attempt += 1

    reviewed = submitted + timedelta(days=1 + ((i * 3) % 12)) if status != "pending" else None

    apps.append(
        {
            "slot": slot,
            "type": "new",          # renewals are decided below, once the timeline is known
            "status": status,
            "submitted": submitted,
            "reviewed": reviewed,
            "index": i,
        }
    )

# Order chronologically: the generator must insert a predecessor application
# before the renewal that replaces it.
apps.sort(key=lambda a: (a["submitted"], a["index"]))
for idx, a in enumerate(apps):
    a["seq"] = idx

# Decide which applications are renewals: a renewal is only created when the same
# driver already has an *approved* application earlier in the timeline and the
# predecessor is not already being renewed by another open application.
for a in apps:
    email = a["slot"]["email"]

    candidates = [
        seq
        for seq in approved_by_driver.get(email, [])
        if apps[seq]["status"] == "approved" and seq not in pending_predecessors
    ]
    candidate = candidates[-1] if candidates else None

    if candidate is not None and a["index"] % 3 != 0:
        a["type"] = "renewal"
        a["predecessor"] = candidate
        if a["status"] == "pending":
            pending_predecessors.add(candidate)

    if a["status"] == "approved":
        approved_by_driver.setdefault(email, []).append(a["seq"])
        pending_drivers.discard(email)
    elif a["status"] == "pending":
        pending_drivers.add(email)

    a.setdefault("predecessor", None)

SEQ_BY_INDEX = {a["seq"]: a for a in apps}

new_count = sum(1 for a in apps if a["type"] == "new")
renewal_count = sum(1 for a in apps if a["type"] == "renewal")
assert new_count + renewal_count == len(apps)

w("-- ---------------------------------------------------------------------------")
w(f"-- 4. Demonstration applications ({len(apps)} records: {new_count} new / {renewal_count} renewals),")
w("--    the four documentary requirements of each, and the franchise records")
w("--    issued on approval.")
w("--    Submitted over a two-year window with a seasonal renewal peak so that the")
w("--    descriptive analytics have a realistic shape. Renewals reference the")
w("--    franchise record of the driver's earlier approved application.")
w("-- ---------------------------------------------------------------------------")
w("create temporary table seed_apps (")
w("  ordinal          integer primary key,")
w("  driver_email     text not null,")
w("  toda_code        text not null,")
w("  application_type public.application_type not null,")
w("  status           public.application_status not null,")
w("  submitted_at     timestamptz not null,")
w("  reviewed_at      timestamptz,")
w("  plate_number     text not null,")
w("  vehicle_make     text not null,")
w("  vehicle_model    text not null,")
w("  vehicle_year     smallint not null,")
w("  vehicle_color    text not null,")
w("  engine_number    text not null,")
w("  chassis_number   text not null,")
w("  seating_capacity smallint not null,")
w("  predecessor_seq  integer")
w(") on commit drop;")
w("")

rows = []
for a in apps:
    slot = a["slot"]
    submitted = datetime(a["submitted"].year, a["submitted"].month, a["submitted"].day, 9, 0, tzinfo=timezone.utc)
    reviewed = (
        datetime(a["reviewed"].year, a["reviewed"].month, a["reviewed"].day, 14, 30, tzinfo=timezone.utc)
        if a["reviewed"]
        else None
    )
    reviewed_sql = f"'{reviewed.isoformat()}'" if reviewed else "null"
    predecessor_sql = str(a["predecessor"]) if a["predecessor"] is not None else "null"
    rows.append(
        f"  ({a['seq']}, '{slot['email']}', '{slot['toda']}', '{a['type']}', '{a['status']}', "
        f"'{submitted.isoformat()}', {reviewed_sql}, "
        f"'{esc(slot['plate'])}', '{esc(slot['make'])}', '{esc(slot['model'])}', {slot['year']}, "
        f"'{esc(slot['color'])}', '{slot['engine']}', '{slot['chassis']}', {slot['capacity']}, {predecessor_sql})"
    )
w("insert into seed_apps (ordinal, driver_email, toda_code, application_type, status, submitted_at, reviewed_at, plate_number, vehicle_make, vehicle_model, vehicle_year, vehicle_color, engine_number, chassis_number, seating_capacity, predecessor_seq) values")
w(",\n".join(rows) + ";")
w("")

w("""do $$
declare
  r              record;
  v_app_id       uuid;
  v_record_id    uuid;
  v_app_number   text;
  v_fr_number    text;
  v_year         integer;
  v_app_seq      integer;
  v_fr_seq       integer;
  v_verified_at  timestamptz;
  v_actor        uuid;
  v_doc          public.document_type;
  v_reason       text;
  v_predecessor  uuid;
begin
  create temporary table if not exists seed_counters (
    calendar_year integer primary key,
    app_counter   integer not null default 0,
    fr_counter    integer not null default 0
  ) on commit drop;

  create temporary table if not exists seed_ids (
    ordinal   integer primary key,
    app_id    uuid not null
  ) on commit drop;

  for r in select * from seed_apps order by submitted_at, ordinal
  loop
    v_year := extract(year from r.submitted_at)::integer;

    insert into seed_counters (calendar_year) values (v_year)
    on conflict (calendar_year) do nothing;

    update seed_counters set app_counter = app_counter + 1
     where calendar_year = v_year
    returning app_counter into v_app_seq;

    v_app_number := 'APP-' || v_year || '-' || lpad(v_app_seq::text, 6, '0');

    select id into v_actor
      from public.profiles
     where lower(email) = lower(r.driver_email);

    v_predecessor := null;
    if r.predecessor_seq is not null then
      select fr.id into v_predecessor
        from public.franchise_records fr
        join seed_ids si on si.app_id = fr.application_id
       where si.ordinal = r.predecessor_seq;
    end if;

    insert into public.franchise_applications (
      application_number, applicant_id, application_type, status, toda_id,
      renewal_of_record_id,
      operator_first_name, operator_middle_name, operator_last_name,
      operator_contact_number, operator_address_line, operator_barangay_code, operator_email,
      vehicle_make, vehicle_model, vehicle_year, vehicle_color,
      plate_number, engine_number, chassis_number, seating_capacity,
      submitted_at, created_at
    )
    select
      v_app_number, p.id, r.application_type, 'pending', t.id,
      v_predecessor,
      p.first_name, p.middle_name, p.last_name,
      coalesce(p.contact_number, '09180000000'),
      coalesce(p.address_line, 'Purok 1') || ', ' || t.name,
      p.barangay_code, p.email,
      r.vehicle_make, r.vehicle_model, r.vehicle_year, r.vehicle_color,
      r.plate_number, r.engine_number, r.chassis_number, r.seating_capacity,
      r.submitted_at, r.submitted_at
      from public.profiles p
      join public.todas t on t.code = r.toda_code
     where p.id = v_actor
    returning id into v_app_id;

    insert into seed_ids (ordinal, app_id) values (r.ordinal, v_app_id);

    -- The four documentary requirements
    for v_doc in
      select * from unnest(enum_range(null::public.document_type)) as dt(document_type)
    loop
      insert into public.franchise_documents (
        application_id, document_type, storage_path, file_name, file_size_bytes, mime_type,
        uploaded_at
      )
      values (
        v_app_id, v_doc,
        v_actor::text || '/' || v_app_id::text || '/' || v_doc::text || '-' ||
          extract(epoch from r.submitted_at)::bigint || '.pdf',
        v_doc::text || '.pdf',
        180000 + (r.ordinal * 977) % 400000,
        'application/pdf',
        r.submitted_at
      );
    end loop;

    if r.status <> 'pending' then
      -- Verification staff process the documents before deciding.
      select id into v_actor
        from public.profiles
       where role in ('staff', 'administrator')
       order by email
       limit 1 offset (r.ordinal % 4);

      v_verified_at := r.reviewed_at - interval '1 day';

      update public.franchise_documents
         set verification_status = 'verified',
             verified_by = v_actor,
             verified_at = v_verified_at
       where application_id = v_app_id
         and verification_status = 'pending';

      if r.status = 'approved' then
        update seed_counters set fr_counter = fr_counter + 1
         where calendar_year = v_year
        returning fr_counter into v_fr_seq;

        v_fr_number := 'MAB-TR-' || v_year || '-' || lpad(v_fr_seq::text, 6, '0');

        insert into public.franchise_records (
          application_id, operator_id, toda_id, franchise_number, verification_code,
          issued_at, expires_at, created_at
        )
        select a.id,
               a.applicant_id,
               a.toda_id,
               v_fr_number,
               public.fn_generate_verification_code(),
               r.reviewed_at,
               r.reviewed_at + make_interval(months => 12),
               r.reviewed_at
          from public.franchise_applications a
         where a.id = v_app_id
        returning id into v_record_id;

        -- Final status transition: fires exactly the same audit and notification
        -- triggers that the staff approval function fires in production.
        update public.franchise_applications
           set status = 'approved',
               reviewed_by = v_actor,
               reviewed_at = r.reviewed_at,
               review_started_at = r.reviewed_at - interval '1 day',
               review_started_by = v_actor
         where id = v_app_id;

        -- Forward link on the predecessor: "this franchise was renewed by …".
        -- No other column of the predecessor is touched.
        if v_predecessor is not null then
          update public.franchise_records
             set renewed_by_record_id = v_record_id
           where id = v_predecessor
             and renewed_by_record_id is null;
        end if;

      else
        v_reason := (array[
          'Barangay clearance presented has already expired; please submit a clearance issued within the current year.',
          'Photocopy of the Certificate of Registration is not legible; a clear copy or scanned original is required.',
          'Registered vehicle owner differs from the declared operator; please submit a deed of sale or authority to operate.',
          'Cedula presented belongs to a different individual; please upload the operator''s own cedula.',
          'Chassis number declared in the application does not match the OR/CR on file; please verify and re-submit.'
        ])[(r.ordinal % 5) + 1];

        update public.franchise_applications
           set status = 'rejected',
               rejection_reason = v_reason,
               reviewed_by = v_actor,
               reviewed_at = r.reviewed_at
         where id = v_app_id;
      end if;
    end if;
  end loop;

  -- Align the production counters with the seeded data so that live submissions
  -- continue the numbering without collisions. franchise_number_sequences is
  -- keyed by calendar year and holds one column per series.
  insert into public.franchise_number_sequences (
    calendar_year, last_value, last_application_value
  )
  select s.yr, s.fr_max, s.app_max
    from (
      select coalesce(fr.yr, ap.yr) as yr,
             coalesce(fr.fr_max, 0) as fr_max,
             coalesce(ap.app_max, 0) as app_max
        from (
          select extract(year from r.issued_at)::integer as yr,
                 max(substring(r.franchise_number from '([0-9]+)$')::integer) as fr_max
            from public.franchise_records r
           group by 1
        ) fr
        full join (
          select extract(year from a.submitted_at)::integer as yr,
                 max(substring(a.application_number from '([0-9]+)$')::integer) as app_max
            from public.franchise_applications a
           group by 1
        ) ap on ap.yr = fr.yr
    ) s
  on conflict (calendar_year) do update
    set last_value = greatest(public.franchise_number_sequences.last_value, excluded.last_value),
        last_application_value = greatest(
          public.franchise_number_sequences.last_application_value,
          excluded.last_application_value
        ),
        updated_at = now();
end
$$;""")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- 5. Verification codes for manual QR testing (development aid)")
w("--    Run:  select franchise_number, verification_code from public.franchise_records limit 5;")
w("-- ---------------------------------------------------------------------------")
w("")
w("-- ---------------------------------------------------------------------------")
w("-- 6. Housekeeping: the seeding helper is not part of the deployed schema.")
w("-- ---------------------------------------------------------------------------")
w("drop function if exists public.seed_create_auth_user(text, text, public.user_role, text, text, text, text, text, text, timestamptz);")
w("")
w("commit;")
w("")
w("-- Reminder: demonstration credentials are listed in docs/deployment.md and")
w("-- must never be used in a live deployment.")

output = "\n".join(lines) + "\n"

with open("supabase/seed.sql", "w", encoding="utf-8") as handle:
    handle.write(output)

member_total = sum(t[3] for t in TODAS)
approved = sum(1 for a in apps if a["status"] == "approved")
pending = sum(1 for a in apps if a["status"] == "pending")
rejected = sum(1 for a in apps if a["status"] == "rejected")
print(f"seed.sql written: {len(output.splitlines())} lines, {len(output)/1024:.1f} KiB")
print(f"TODAs: {len(TODAS)}  masterlist members: {member_total}")
print(f"drivers: {len(driver_slots)}  applications: {len(apps)} (new {new_count} / renewal {renewal_count})")
print(f"status: approved {approved} / pending {pending} / rejected {rejected}")
