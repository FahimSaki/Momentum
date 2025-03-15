-- Drop existing tables if they exist
drop table if exists public.habits;
drop table if exists public.app_settings;

-- Create habits table without user_id
create table public.habits (
    id uuid default uuid_generate_v4() primary key,
    name text not null,
    completed_days text[] default array[]::text[],
    last_completed_date timestamp with time zone,
    is_archived boolean default false,
    archived_at timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- Create app_settings table without user_id
create table public.app_settings (
    id uuid default uuid_generate_v4() primary key,
    first_launch_date timestamp with time zone not null,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- Create function to handle updated timestamps
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = timezone('utc'::text, now());
    return new;
end;
$$ language plpgsql security definer;

-- Create triggers for updated_at columns
create trigger handle_updated_at
    before update on public.habits
    for each row execute procedure public.handle_updated_at();

create trigger handle_updated_at
    before update on public.app_settings
    for each row execute procedure public.handle_updated_at();

-- Enable Row Level Security
alter table public.habits enable row level security;
alter table public.app_settings enable row level security;

-- Create policies for public access with RLS enabled
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

-- Create indexes for better performance
create index habits_completed_date_idx on public.habits(last_completed_date);