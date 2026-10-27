-- BloodConnect database schema (Supabase / Postgres)
-- Supabase Dashboard > SQL Editor e eta paste kore Run korun.

create extension if not exists "uuid-ossp";

-- ============ PROFILES (donors) ============
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null unique,
  blood_group text not null check (blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  area_name text,
  latitude double precision,
  longitude double precision,
  radius_km int not null default 10,
  last_donation_date date,           -- self-declared
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============ BLOOD REQUESTS ============
create table public.blood_requests (
  id uuid primary key default uuid_generate_v4(),
  requester_id uuid references auth.users(id) on delete set null, -- null = account chara post
  patient_name text not null,
  blood_group text not null check (blood_group in ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  units int not null default 1 check (units between 1 and 10),
  hospital text not null,
  latitude double precision not null,
  longitude double precision not null,
  note text,
  status text not null default 'open' check (status in ('open','fulfilled','cancelled')),
  created_at timestamptz not null default now()
);

-- ============ REQUEST CONTACTS (phone number alada table e, accept er age hide thake) ============
create table public.request_contacts (
  request_id uuid primary key references public.blood_requests(id) on delete cascade,
  phone text not null,
  created_at timestamptz not null default now()
);

-- ============ ACCEPTS (donor request accept kore) ============
create table public.request_accepts (
  id uuid primary key default uuid_generate_v4(),
  request_id uuid not null references public.blood_requests(id) on delete cascade,
  donor_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (request_id, donor_id)
);

-- ============ CHAT MESSAGES ============
-- room_id = request_id + donor_id; requester account chara hole device_id diye chat hoy
create table public.messages (
  id uuid primary key default uuid_generate_v4(),
  request_id uuid not null references public.blood_requests(id) on delete cascade,
  donor_id uuid not null references auth.users(id) on delete cascade,
  sender text not null check (sender in ('donor','requester')),
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

-- ============ LIVE LOCATIONS (shudhu accept korar por) ============
create table public.live_locations (
  request_id uuid not null references public.blood_requests(id) on delete cascade,
  donor_id uuid not null references auth.users(id) on delete cascade,
  who text not null check (who in ('donor','requester')),
  latitude double precision not null,
  longitude double precision not null,
  updated_at timestamptz not null default now(),
  primary key (request_id, donor_id, who)
);

-- ============ BLOOD COMPATIBILITY ============
-- recipient group => je je group dite pare
create or replace function public.compatible_donor_groups(recipient text)
returns text[] language sql immutable as $$
  select case recipient
    when 'O+'  then array['O+','O-']
    when 'O-'  then array['O-']
    when 'A+'  then array['A+','A-','O+','O-']
    when 'A-'  then array['A-','O-']
    when 'B+'  then array['B+','B-','O+','O-']
    when 'B-'  then array['B-','O-']
    when 'AB+' then array['A+','A-','B+','B-','AB+','AB-','O+','O-']
    when 'AB-' then array['A-','B-','AB-','O-']
    else array[]::text[]
  end;
$$;

-- ============ DISTANCE (haversine, km) ============
create or replace function public.distance_km(lat1 double precision, lon1 double precision,
                                              lat2 double precision, lon2 double precision)
returns double precision language sql immutable as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lon2 - lon1) / 2), 2)
  ));
$$;

-- ============ DONOR ELIGIBLE? (4 mash rule) ============
create or replace function public.is_donor_eligible(last_date date)
returns boolean language sql immutable as $$
  select last_date is null or last_date <= (current_date - interval '4 months');
$$;

-- ============ MATCHING: ei donor er jonno open request gulo ============
create or replace function public.matching_requests_for_me()
returns table (
  id uuid, patient_name text, blood_group text, units int, hospital text,
  latitude double precision, longitude double precision, note text,
  created_at timestamptz, distance double precision, exact_match boolean
)
language sql security definer set search_path = public as $$
  select r.id, r.patient_name, r.blood_group, r.units, r.hospital,
         r.latitude, r.longitude, r.note, r.created_at,
         distance_km(p.latitude, p.longitude, r.latitude, r.longitude) as distance,
         (r.blood_group = p.blood_group) as exact_match
  from blood_requests r
  join profiles p on p.id = auth.uid()
  where r.status = 'open'
    and p.is_available
    and is_donor_eligible(p.last_donation_date)
    and p.blood_group = any (compatible_donor_groups(r.blood_group))
    and distance_km(p.latitude, p.longitude, r.latitude, r.longitude) <= p.radius_km
  order by exact_match desc, distance asc, r.created_at desc;
$$;

-- ============ SECURITY (Row Level Security) ============
alter table public.profiles enable row level security;
alter table public.blood_requests enable row level security;
alter table public.request_accepts enable row level security;
alter table public.messages enable row level security;
alter table public.live_locations enable row level security;
alter table public.request_contacts enable row level security;

-- profiles: nijer profile nijei dekhe/edit kore
create policy "own profile read" on public.profiles for select using (auth.uid() = id);
create policy "own profile insert" on public.profiles for insert with check (auth.uid() = id);
create policy "own profile update" on public.profiles for update using (auth.uid() = id);
-- requester shudhu tar request e accept kora donor der profile dekhte pare
create policy "requester reads accepted donors" on public.profiles for select using (
  exists (
    select 1 from request_accepts a
    join blood_requests r on r.id = a.request_id
    where a.donor_id = profiles.id and r.requester_id = auth.uid()
  )
);

-- request_contacts: shudhu requester ar accept kora donor phone dekhte pare
create policy "contacts insert" on public.request_contacts for insert with check (
  exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid())
);
create policy "contacts read" on public.request_contacts for select using (
  exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid())
  or exists (select 1 from request_accepts a where a.request_id = request_contacts.request_id and a.donor_id = auth.uid())
);

-- blood_requests: shobai dekhte pare (phone number app e accept er age hide kora hoy), signed-in or anon post korte pare
create policy "requests read" on public.blood_requests for select using (true);
create policy "requests insert" on public.blood_requests for insert
  with check (requester_id is null or requester_id = auth.uid());
create policy "requests update own" on public.blood_requests for update
  using (requester_id = auth.uid());

-- accepts: donor nijer accept dekhe/create kore, requester tar request er accept dekhe
create policy "accepts read" on public.request_accepts for select using (
  donor_id = auth.uid()
  or exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid())
);
create policy "accepts insert" on public.request_accepts for insert with check (donor_id = auth.uid());

-- messages & live_locations: shudhu oi accept er donor ba requester
create policy "messages read" on public.messages for select using (
  donor_id = auth.uid()
  or exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid())
);
-- chat shudhu accept er por
create policy "messages insert" on public.messages for insert with check (
  exists (select 1 from request_accepts a where a.request_id = messages.request_id and a.donor_id = messages.donor_id)
  and (
    donor_id = auth.uid()
    or exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid())
  )
);

create policy "loc read" on public.live_locations for select using (
  donor_id = auth.uid()
  or exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid())
);
-- location share shudhu accept er por, ar request 'open' thakle
create policy "loc write" on public.live_locations for insert with check (
  exists (select 1 from request_accepts a where a.request_id = live_locations.request_id and a.donor_id = live_locations.donor_id)
  and exists (select 1 from blood_requests r2 where r2.id = request_id and r2.status = 'open')
  and (
    (who = 'donor' and donor_id = auth.uid())
    or (who = 'requester' and exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid()))
  )
);
create policy "loc update" on public.live_locations for update using (
  exists (select 1 from blood_requests r2 where r2.id = request_id and r2.status = 'open')
  and (
    (who = 'donor' and donor_id = auth.uid())
    or (who = 'requester' and exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid()))
  )
);
create policy "loc delete" on public.live_locations for delete using (
  (who = 'donor' and donor_id = auth.uid())
  or (who = 'requester' and exists (select 1 from blood_requests r where r.id = request_id and r.requester_id = auth.uid()))
);

-- ============ RATE LIMIT: ek ghonta e ek phone theke 3 ta request er beshi na ============
create or replace function public.limit_requests() returns trigger language plpgsql as $$
begin
  if (select count(*) from request_contacts
      where phone = new.phone
        and created_at > now() - interval '1 hour') >= 3 then
    raise exception 'Too many requests from this phone. Please try again later.';
  end if;
  return new;
end $$;

create trigger trg_limit_requests before insert on public.request_contacts
  for each row execute function public.limit_requests();

-- ============ REALTIME ============
alter publication supabase_realtime add table public.blood_requests;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.live_locations;
