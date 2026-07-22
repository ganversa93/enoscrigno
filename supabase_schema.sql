-- ════════════════════════════════════════════
--  ENOSCRIGNO — Schema Supabase
--  Esegui questo script nel SQL Editor di Supabase:
--  supabase.com → progetto → SQL Editor → New query → incolla → Run
-- ════════════════════════════════════════════

-- ── PROFILES (dati sommelier, estende auth.users) ──
create table if not exists public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  full_name          text,
  assoc              text,                     -- AIS | FISAR | ONAV | FIS | ''
  card               text,                     -- numero tessera
  delegazione        text,                     -- delegazione da menu
  delegazione_custom text,                     -- delegazione testo libero
  ai_scan_enabled    boolean not null default false,  -- accesso alla scansione AI (funzione premium)
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);

-- ── WINES ──
create table if not exists public.wines (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,

  -- identità
  name          text not null,
  producer      text,
  vintage       integer,
  type          text,             -- Rosso | Bianco | Rosato | Spumante | Dolce | Passito | Altro
  doc           text,
  grapes        text,

  -- provenienza
  region        text,
  province      text,             -- solo Italia (es. 'Cuneo' per il Barolo)
  country       text default 'Italia',

  -- tecnico
  abv           numeric(4,1),
  format        text default '750 ml',

  -- cantina
  price         numeric(8,2),
  qty           integer default 1,
  date          date,             -- data acquisto
  shop          text,             -- luogo acquisto
  drink         text,             -- finestra consumo

  -- degustazione
  tasting_date  date,
  tasting_place text,
  pairing       text,             -- abbinamenti cibo (chip predefiniti + testo libero, separati da virgola)
  deg_schema    text default 'free',   -- ais | fisar | free

  -- scheda AIS
  ais_params    jsonb,
  ais_score     integer,
  olf_note      text,
  gust_note     text,

  -- scheda FISAR
  fisar_params  jsonb,
  fisar_score   integer,
  fp_note       text,

  -- valutazione libera
  score         integer,
  notes         text,
  tags          text,

  -- immagini (base64 o URL storage)
  front_img     text,
  back_img      text,

  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ── INDICI ──
create index if not exists wines_user_id_idx on public.wines(user_id);
create index if not exists wines_created_at_idx on public.wines(user_id, created_at desc);

-- ── ROW LEVEL SECURITY ──
-- Ogni utente vede e modifica SOLO i propri dati.

alter table public.profiles enable row level security;
alter table public.wines     enable row level security;

-- Profiles: l'utente può leggere e scrivere solo il proprio profilo
create policy "profiles: own read"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles: own insert"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles: own update"
  on public.profiles for update
  using (auth.uid() = id);

-- Wines: l'utente può leggere e modificare solo i propri vini
create policy "wines: own read"
  on public.wines for select
  using (auth.uid() = user_id);

create policy "wines: own insert"
  on public.wines for insert
  with check (auth.uid() = user_id);

create policy "wines: own update"
  on public.wines for update
  using (auth.uid() = user_id);

create policy "wines: own delete"
  on public.wines for delete
  using (auth.uid() = user_id);

-- ── TRIGGER: aggiorna updated_at automaticamente ──
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger wines_updated_at
  before update on public.wines
  for each row execute function public.set_updated_at();

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ── TRIGGER: crea automaticamente il profilo alla registrazione ──
-- Questo è FONDAMENTALE: se la conferma email è attiva, il client
-- non ha ancora una sessione autenticata subito dopo la registrazione,
-- quindi un salvataggio del profilo fatto dal browser verrebbe bloccato
-- dalla Row Level Security. Questo trigger gira lato server con
-- privilegi elevati (SECURITY DEFINER) e quindi funziona sempre,
-- indipendentemente dalla conferma email.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, assoc, card, delegazione, delegazione_custom)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'assoc', ''),
    coalesce(new.raw_user_meta_data->>'card', ''),
    '', ''
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ════════════════════════════════════════════
-- FATTO! Ora vai in Authentication → Email Templates
-- e personalizza il template di conferma email se vuoi.
-- ════════════════════════════════════════════

-- ════════════════════════════════════════════
-- MIGRAZIONE — se il database esiste già (tabelle già create in
-- precedenza), esegui SOLO questa riga per aggiungere il nuovo
-- campo "abbinamento cibo" senza perdere i dati esistenti:
-- ════════════════════════════════════════════
alter table public.wines add column if not exists pairing text;

-- ════════════════════════════════════════════
-- SCAN USAGE — contatore per limitare la scansione etichette AI
-- Tiene traccia di quante scansioni sono state fatte, per utente
-- e in totale, in ogni mese ('2026-07' ecc). Scritto SOLO dalla
-- Edge Function tramite la service role key: nessun accesso diretto
-- dal client, quindi RLS resta abilitata senza policy (deny-all).
-- ════════════════════════════════════════════
create table if not exists public.scan_usage (
  scope  text not null,   -- 'global' oppure lo user_id del sommelier
  period text not null,   -- mese in formato 'YYYY-MM'
  count  integer not null default 0,
  updated_at timestamptz default now(),
  primary key (scope, period)
);
alter table public.scan_usage enable row level security;
-- Nessuna policy = nessun accesso dal client (anon/authenticated).
-- Solo la Edge Function, che usa la service role key, può leggere/scrivere.

-- ════════════════════════════════════════════
-- AI SCAN — flag premium per abilitare la scansione etichette
-- Se il database esiste già, esegui questa riga per aggiungere la
-- colonna senza perdere i dati esistenti. Di default è FALSE per
-- tutti (anche gli utenti già registrati).
-- ════════════════════════════════════════════
alter table public.profiles add column if not exists ai_scan_enabled boolean not null default false;

-- Poi abilita la scansione AI solo per il tuo account, sostituendo
-- l'email con la tua:
-- update public.profiles set ai_scan_enabled = true
--   where id = (select id from auth.users where email = 'TUA_EMAIL@esempio.it');

-- ════════════════════════════════════════════
-- PROVINCIA — se il database esiste già, esegui questa riga per
-- aggiungere il campo provincia (rilevante solo per l'Italia)
-- ════════════════════════════════════════════
alter table public.wines add column if not exists province text;
