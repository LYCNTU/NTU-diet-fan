-- DIET 飯 / PostgreSQL + Supabase target schema. Not connected in local demo.
-- Production rollout must add transactional RPCs, authorization tests, and payment integration.
create table profiles (
 id uuid primary key references auth.users(id), display_name text not null,
 preferences jsonb not null default '[]', excluded_ingredients jsonb not null default '[]',
 notification_enabled boolean not null default true, created_at timestamptz not null default now()
);
create table saved_locations (id uuid primary key default gen_random_uuid(),user_id uuid references profiles(id),label text not null,latitude double precision not null,longitude double precision not null);
create table restaurants (id uuid primary key default gen_random_uuid(),name text not null,category text,latitude double precision,longitude double precision);
create table foods (id uuid primary key default gen_random_uuid(),restaurant_id uuid references restaurants(id),name text not null,price_twd integer not null check(price_twd>=0),tags jsonb not null default '[]',stock integer not null default 0 check(stock>=0));
create table runner_routes (id uuid primary key default gen_random_uuid(),runner_id uuid not null references profiles(id),start_point jsonb not null,end_point jsonb not null,restaurant_id uuid references restaurants(id),departure_at timestamptz not null,max_detour_minutes integer not null check(max_detour_minutes>=0),capacity integer not null check(capacity between 1 and 3));
create table orders (id uuid primary key default gen_random_uuid(),buyer_id uuid not null references profiles(id),runner_id uuid references profiles(id),route_id uuid references runner_routes(id),food_id uuid references foods(id),item_note text not null,food_price_twd integer not null check(food_price_twd>=0),fee_twd integer not null check(fee_twd>=0),destination jsonb not null,deadline timestamptz not null,status integer not null default 0 check(status between 0 and 7),cancelled boolean not null default false,created_at timestamptz not null default now(),completed_at timestamptz,check(buyer_id is distinct from runner_id));
-- Keep pickup secrets separate from general order reads. Never send the hash to clients.
create table order_secrets (order_id uuid primary key references orders(id),pickup_code_hash text not null,failed_attempts integer not null default 0);
create table order_events (id uuid primary key default gen_random_uuid(),order_id uuid not null references orders(id),actor_id uuid references profiles(id),event_type text not null,payload jsonb,created_at timestamptz not null default now());
create table messages (id uuid primary key default gen_random_uuid(),order_id uuid not null references orders(id),sender_id uuid references profiles(id),body text not null,created_at timestamptz not null default now());
create table ratings (order_id uuid references orders(id),author_id uuid references profiles(id),recipient_id uuid references profiles(id),stars integer not null check(stars between 1 and 5),tags jsonb not null default '[]',primary key(order_id,author_id));
create table meal_groups (id uuid primary key default gen_random_uuid(),restaurant_id uuid references restaurants(id),destination_zone text not null,target_members integer not null default 5);
create table group_members (group_id uuid references meal_groups(id),user_id uuid references profiles(id),primary key(group_id,user_id));
create table food_history (id uuid primary key default gen_random_uuid(),user_id uuid references profiles(id),food_id uuid references foods(id),completed_order_id uuid references orders(id),eaten_at timestamptz not null default now());
-- Enable RLS everywhere. Tables without a policy stay deny-by-default.
alter table profiles enable row level security;
alter table saved_locations enable row level security;
alter table restaurants enable row level security;
alter table foods enable row level security;
alter table runner_routes enable row level security;
alter table orders enable row level security;
alter table order_secrets enable row level security;
alter table order_events enable row level security;
alter table messages enable row level security;
alter table ratings enable row level security;
alter table meal_groups enable row level security;
alter table group_members enable row level security;
alter table food_history enable row level security;
create policy own_profile on profiles for all to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy own_locations on saved_locations for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy view_restaurants on restaurants for select to authenticated using(true);
create policy view_foods on foods for select to authenticated using(true);
create policy view_participant_orders on orders for select to authenticated using(buyer_id=auth.uid() or runner_id=auth.uid());
create policy view_participant_messages on messages for select to authenticated using(exists(select 1 from orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.runner_id=auth.uid())));
create policy send_participant_messages on messages for insert to authenticated with check(sender_id=auth.uid() and exists(select 1 from orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.runner_id=auth.uid())));
-- Orders, inventory, route capacity and pickup verification must be mutated only through
-- authenticated server transactions/RPCs. Lock affected rows and use idempotency keys.
-- Do not grant general client updates to orders or secrets. A migration alone is not a launch-ready backend.
