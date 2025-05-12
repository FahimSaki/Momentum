-- Drop existing tables if they exist
drop table if exists public.habits;
drop table if exists public.app_settings;
drop table if exists public.devices;

-- Create habits table
create table public.habits (
    id serial primary key,
    name text not null,
    completed_days text[] default array[]::text[],
    last_completed_date timestamp with time zone,
    is_archived boolean default false,
    archived_at timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    device_id text
);

-- Create app_settings table
create table public.app_settings (
    id serial primary key,
    first_launch_date timestamp with time zone not null,
    created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Create devices table if not exists
create table if not exists public.devices (
    id serial primary key,
    device_id text not null unique,
    last_seen timestamp with time zone default timezone('utc'::text, now())
);

-- Enable Row Level Security
alter table public.habits enable row level security;
alter table public.app_settings enable row level security;
alter table public.devices enable row level security;

-- Create policies for habits table
create policy "Enable read access for all users"
    on public.habits for select
    to anon, authenticated
    using (true);

create policy "Enable insert access for all users"
    on public.habits for insert
    to anon, authenticated
    with check (true);

create policy "Enable update access for all users"
    on public.habits for update
    to anon, authenticated
    using (true);

create policy "Enable delete access for all users"
    on public.habits for delete
    to anon, authenticated
    using (true);

-- Create policies for app_settings table
create policy "Enable read access for settings"
    on public.app_settings for select
    to anon, authenticated
    using (true);

create policy "Enable insert access for settings"
    on public.app_settings for insert
    to anon, authenticated
    with check (true);

create policy "Enable update access for settings"
    on public.app_settings for update
    to anon, authenticated
    using (true);

-- Create policies for devices table
create policy "Enable read access for devices"
    on public.devices for select
    to anon, authenticated
    using (true);

create policy "Enable insert/update access for devices"
    on public.devices for insert
    to anon, authenticated
    with check (true);

create policy "Enable update access for devices"
    on public.devices for update
    to anon, authenticated
    using (true);

-- Create indexes for better performance
create index habits_completed_date_idx on public.habits(last_completed_date);
create index habits_archived_idx on public.habits(is_archived, archived_at);
create index if not exists devices_device_id_idx on public.devices(device_id);
create index if not exists habits_device_id_idx on public.habits(device_id);