-- Jalankan sekali di Supabase Dashboard > SQL Editor.
create table if not exists public.inventory_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  business_profile_id uuid not null,
  name text not null,
  normalized_name text not null,
  category text not null default 'lainnya',
  unit text,
  current_stock numeric not null default 0,
  minimum_stock numeric not null default 0,
  last_unit_price numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_profile_id, normalized_name)
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.inventory_products(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  business_profile_id uuid not null,
  movement_type text not null check (movement_type in ('in', 'out', 'adjustment')),
  quantity numeric not null,
  note text,
  reference_id uuid,
  created_at timestamptz not null default now()
);

alter table public.inventory_products enable row level security;
alter table public.inventory_movements enable row level security;

create policy "Users manage their inventory products" on public.inventory_products
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage their inventory movements" on public.inventory_movements
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.record_inventory_movement(
  p_business_profile_id uuid, p_name text, p_normalized_name text,
  p_category text, p_unit text, p_quantity numeric, p_movement_type text,
  p_unit_price numeric default 0, p_note text default null, p_reference_id uuid default null
) returns uuid language plpgsql security invoker set search_path = public as $$
declare product_row public.inventory_products;
declare signed_quantity numeric;
begin
  if auth.uid() is null or p_quantity <= 0 then raise exception 'Invalid inventory movement'; end if;
  signed_quantity := case when p_movement_type = 'out' then -p_quantity else p_quantity end;
  insert into inventory_products (user_id, business_profile_id, name, normalized_name, category, unit, current_stock, last_unit_price)
  values (auth.uid(), p_business_profile_id, p_name, p_normalized_name, coalesce(p_category, 'lainnya'), p_unit, signed_quantity, coalesce(p_unit_price, 0))
  on conflict (business_profile_id, normalized_name) do update set
    current_stock = inventory_products.current_stock + signed_quantity,
    name = excluded.name, category = excluded.category,
    unit = coalesce(excluded.unit, inventory_products.unit),
    last_unit_price = case when excluded.last_unit_price > 0 then excluded.last_unit_price else inventory_products.last_unit_price end,
    updated_at = now()
  returning * into product_row;
  insert into inventory_movements (product_id, user_id, business_profile_id, movement_type, quantity, note, reference_id)
  values (product_row.id, auth.uid(), p_business_profile_id, p_movement_type, signed_quantity, p_note, p_reference_id);
  return product_row.id;
end; $$;
