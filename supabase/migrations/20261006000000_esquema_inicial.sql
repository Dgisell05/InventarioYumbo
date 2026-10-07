-- =============================================================================
-- Inventario Yumbo (app simple) · Esquema inicial
-- -----------------------------------------------------------------------------
-- Modelo: un producto es tipo + color (ej. "Teja arquitectónica roja").
--   · Productos con unidad 'm'   : el stock se lleva en METROS LINEALES.
--                                   Cada movimiento guarda unidades × largo.
--                                   Así un corte (una teja de 6 m en dos de 3 m)
--                                   no altera el stock; solo el sobrante lo baja.
--   · Productos con unidad 'und' : el stock se lleva en UNIDADES (tornillería,
--                                   tejas UPVC compradas en largo fijo).
-- Todo movimiento de inventario vive en la tabla `movimientos`. Las demás tablas
-- (despachos, cortes) crean sus movimientos por trigger o por función.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Catálogo
-- -----------------------------------------------------------------------------
create table public.productos (
  id               uuid primary key default gen_random_uuid(),
  codigo           text not null unique,
  nombre           text not null,
  categoria        text not null,                     -- TEJAS, PERFILERIA, PERLINES, UPVC, TORNILLERIA, OTRO
  tipo             text not null,                     -- ARQUITECTONICA, MASTER, OMEGAS, PERFIL 120*50*1.5 ...
  color            text,                              -- ROJA, AZUL, ALUMINIO ... (null si no aplica)
  unidad           text not null default 'm' check (unidad in ('m', 'und')),
  largo_estandar_m numeric check (largo_estandar_m is null or largo_estandar_m > 0),
  precio_m         numeric check (precio_m is null or precio_m >= 0),   -- precio por metro (o por unidad si unidad='und')
  stock_minimo     numeric not null default 0 check (stock_minimo >= 0),
  alias            text[] not null default '{}',      -- otras formas de nombrarlo ("teja roja", "omega")
  activo           boolean not null default true,
  created_at       timestamptz not null default now()
);
comment on table public.productos is 'Catálogo. Un producto = categoría + tipo + color. El largo va en cada movimiento, no en el producto.';
comment on column public.productos.alias is 'Nombres alternos que usa el coordinador; se los damos a Claude para que reconozca el producto.';

create table public.clientes (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null unique,
  identificacion text,
  telefono       text,
  ciudad         text,
  activo         boolean not null default true,
  created_at     timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Despachos (orden de salida)
-- -----------------------------------------------------------------------------
-- Contadores transaccionales: si un despacho falla (por ejemplo sin stock) el número NO se pierde.
-- Una secuencia normal de Postgres sí dejaría saltos.
create table public.contadores (
  nombre text primary key,
  valor  bigint not null
);
insert into public.contadores (nombre, valor) values ('despacho', 306);   -- el siguiente será 307
comment on table public.contadores is 'Último número usado por consecutivo. Para reiniciar: update contadores set valor = N-1 where nombre = ''despacho'';';

create or replace function public.siguiente_numero(p_nombre text)
returns bigint language plpgsql as $$
declare
  v bigint;
begin
  update public.contadores set valor = valor + 1 where nombre = p_nombre returning valor into v;
  if v is null then
    raise exception 'Contador % no existe', p_nombre;
  end if;
  return v;
end $$;

create table public.despachos (
  id             uuid primary key default gen_random_uuid(),
  numero         bigint not null unique,                -- lo asigna el trigger desde `contadores`
  fecha          date not null default current_date,
  cliente_id     uuid references public.clientes (id),
  cliente_nombre text not null,                       -- copia del nombre al momento del despacho
  nota           text,
  texto_original text,                                -- lo que escribió el coordinador (si vino por texto)
  estado         text not null default 'confirmado' check (estado in ('confirmado', 'anulado')),
  created_by     uuid references auth.users (id),
  created_at     timestamptz not null default now()
);
comment on column public.despachos.numero is 'Consecutivo automático sin saltos. Arranca en 307 para continuar la numeración del Excel. Cambiar con: update contadores set valor = N-1 where nombre = ''despacho'';';

create or replace function public.despachos_asignar_numero()
returns trigger language plpgsql as $$
begin
  if new.numero is null then
    new.numero := public.siguiente_numero('despacho');
  end if;
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end $$;

create trigger trg_despachos_numero
before insert on public.despachos
for each row execute function public.despachos_asignar_numero();

create table public.despacho_lineas (
  id           uuid primary key default gen_random_uuid(),
  despacho_id  uuid not null references public.despachos (id) on delete cascade,
  producto_id  uuid not null references public.productos (id),
  cantidad_und numeric not null check (cantidad_und > 0),
  largo_m      numeric check (largo_m is null or largo_m > 0),
  metros       numeric,                               -- cantidad_und × largo_m (solo productos en metros)
  precio_m     numeric check (precio_m is null or precio_m >= 0),
  valor_total  numeric,
  orden        int not null default 1
);

-- -----------------------------------------------------------------------------
-- Cortes: una unidad larga se convierte en varias cortas del mismo producto
-- -----------------------------------------------------------------------------
create table public.cortes (
  id               uuid primary key default gen_random_uuid(),
  fecha            date not null default current_date,
  producto_id      uuid not null references public.productos (id),
  cantidad_origen  numeric not null check (cantidad_origen > 0),
  largo_origen_m   numeric not null check (largo_origen_m > 0),
  cantidad_destino numeric not null check (cantidad_destino > 0),
  largo_destino_m  numeric not null check (largo_destino_m > 0),
  sobrante_m       numeric not null default 0 check (sobrante_m >= 0),  -- se calcula: origen − destino
  despacho_id      uuid references public.despachos (id) on delete set null,
  nota             text,
  created_by       uuid references auth.users (id),
  created_at       timestamptz not null default now()
);
comment on table public.cortes is 'Ej: 1 teja de 6 m → 2 de 3 m (sobrante 0). 1 de 6 m → 1 de 4.5 m (sobrante 1.5 m, se registra como merma).';

-- -----------------------------------------------------------------------------
-- Movimientos: el kardex. Todo lo que entra o sale pasa por aquí.
-- -----------------------------------------------------------------------------
create table public.movimientos (
  id           uuid primary key default gen_random_uuid(),
  fecha        date not null default current_date,
  tipo         text not null check (tipo in (
                 'inicial', 'produccion', 'compra', 'ajuste_entrada', 'corte_entrada',   -- entradas
                 'salida', 'merma', 'ajuste_salida', 'corte_salida'                      -- salidas
               )),
  signo        smallint not null,                     -- +1 entrada, −1 salida (lo pone el trigger)
  producto_id  uuid not null references public.productos (id),
  cantidad_und numeric not null check (cantidad_und > 0),
  largo_m      numeric check (largo_m is null or largo_m > 0),
  metros       numeric,                               -- cantidad_und × largo_m si el producto va en metros
  despacho_id  uuid references public.despachos (id) on delete cascade,
  corte_id     uuid references public.cortes (id) on delete cascade,
  nota         text,
  created_by   uuid references auth.users (id),
  created_at   timestamptz not null default now()
);
create index movimientos_producto_fecha_idx on public.movimientos (producto_id, fecha, created_at);
create index movimientos_despacho_idx on public.movimientos (despacho_id);

-- Trigger: calcula signo y metros, exige largo en productos que van por metros.
create or replace function public.movimientos_preparar()
returns trigger language plpgsql as $$
declare
  v_unidad text;
begin
  select unidad into v_unidad from public.productos where id = new.producto_id;
  if v_unidad is null then
    raise exception 'Producto % no existe', new.producto_id;
  end if;

  new.signo := case
    when new.tipo in ('inicial', 'produccion', 'compra', 'ajuste_entrada', 'corte_entrada') then 1
    else -1
  end;

  if v_unidad = 'm' then
    if new.largo_m is null then
      raise exception 'El producto va por metros: indica el largo (m) del movimiento';
    end if;
    new.metros := round(new.cantidad_und * new.largo_m, 3);
  else
    new.metros := null;
  end if;

  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end $$;

create trigger trg_movimientos_preparar
before insert or update on public.movimientos
for each row execute function public.movimientos_preparar();

-- Trigger 1 (BEFORE): valida el corte y calcula el sobrante.
create or replace function public.cortes_preparar()
returns trigger language plpgsql as $$
declare
  v_unidad   text;
  v_sobrante numeric;
begin
  select unidad into v_unidad from public.productos where id = new.producto_id;
  if v_unidad is null then
    raise exception 'Producto % no existe', new.producto_id;
  end if;
  if v_unidad <> 'm' then
    raise exception 'Solo se cortan productos que van por metros';
  end if;

  v_sobrante := round(new.cantidad_origen * new.largo_origen_m - new.cantidad_destino * new.largo_destino_m, 3);
  if v_sobrante < 0 then
    raise exception 'El corte produce más metros (%) de los que entran (%)',
      new.cantidad_destino * new.largo_destino_m, new.cantidad_origen * new.largo_origen_m;
  end if;
  new.sobrante_m := v_sobrante;
  if new.created_by is null then
    new.created_by := auth.uid();
  end if;
  return new;
end $$;

create trigger trg_cortes_preparar
before insert on public.cortes
for each row execute function public.cortes_preparar();

-- Trigger 2 (AFTER): un corte genera sus movimientos
-- (salida del largo origen, entrada del largo destino, merma del sobrante).
create or replace function public.cortes_registrar_movimientos()
returns trigger language plpgsql as $$
begin
  insert into public.movimientos (fecha, tipo, producto_id, cantidad_und, largo_m, corte_id, despacho_id, nota, created_by)
  values (new.fecha, 'corte_salida', new.producto_id, new.cantidad_origen, new.largo_origen_m, new.id, new.despacho_id, new.nota, new.created_by);

  insert into public.movimientos (fecha, tipo, producto_id, cantidad_und, largo_m, corte_id, despacho_id, nota, created_by)
  values (new.fecha, 'corte_entrada', new.producto_id, new.cantidad_destino, new.largo_destino_m, new.id, new.despacho_id, new.nota, new.created_by);

  -- El sobrante se da de baja como merma. Si prefieren guardarlo como retazo vendible,
  -- cambiar 'merma' por 'corte_entrada' con largo = sobrante y cantidad = 1.
  if new.sobrante_m > 0 then
    insert into public.movimientos (fecha, tipo, producto_id, cantidad_und, largo_m, corte_id, despacho_id, nota, created_by)
    values (new.fecha, 'merma', new.producto_id, 1, new.sobrante_m, new.id, new.despacho_id, 'Sobrante de corte', new.created_by);
  end if;
  return new;
end $$;

create trigger trg_cortes_movimientos
after insert on public.cortes
for each row execute function public.cortes_registrar_movimientos();

-- -----------------------------------------------------------------------------
-- Vistas
-- -----------------------------------------------------------------------------
-- Stock por producto: en metros (unidad 'm') o unidades (unidad 'und').
create or replace view public.v_stock with (security_invoker = on) as
select
  p.id            as producto_id,
  p.codigo,
  p.nombre,
  p.categoria,
  p.tipo,
  p.color,
  p.unidad,
  p.largo_estandar_m,
  p.stock_minimo,
  p.activo,
  coalesce(sum(case when m.signo = 1  then coalesce(m.metros, m.cantidad_und) end), 0) as entradas,
  coalesce(sum(case when m.signo = -1 then coalesce(m.metros, m.cantidad_und) end), 0) as salidas,
  coalesce(sum(m.signo * coalesce(m.metros, m.cantidad_und)), 0)                       as saldo,
  coalesce(sum(m.signo * coalesce(m.metros, m.cantidad_und)), 0) < p.stock_minimo      as bajo_minimo,
  max(m.fecha)                                                                           as ultimo_movimiento
from public.productos p
left join public.movimientos m on m.producto_id = p.id
group by p.id;

-- Stock por producto y largo (informativo): cuántas piezas de cada largo deberían quedar.
create or replace view public.v_stock_por_largo with (security_invoker = on) as
select
  p.id      as producto_id,
  p.codigo,
  p.nombre,
  m.largo_m,
  sum(m.signo * m.cantidad_und) as unidades
from public.productos p
join public.movimientos m on m.producto_id = p.id
where p.unidad = 'm' and m.tipo <> 'merma'
group by p.id, m.largo_m
having sum(m.signo * m.cantidad_und) <> 0;

-- Kardex: movimientos con saldo acumulado por producto.
create or replace view public.v_kardex with (security_invoker = on) as
select
  m.id,
  m.fecha,
  m.created_at,
  m.tipo,
  m.signo,
  p.id      as producto_id,
  p.codigo,
  p.nombre,
  p.unidad,
  m.cantidad_und,
  m.largo_m,
  m.metros,
  m.signo * coalesce(m.metros, m.cantidad_und) as movimiento,
  sum(m.signo * coalesce(m.metros, m.cantidad_und))
    over (partition by m.producto_id order by m.fecha, m.created_at) as saldo,
  d.numero  as despacho_numero,
  d.cliente_nombre,
  m.corte_id,
  m.nota
from public.movimientos m
join public.productos p on p.id = m.producto_id
left join public.despachos d on d.id = m.despacho_id
order by m.fecha desc, m.created_at desc;

-- Despachos con totales, para el historial.
create or replace view public.v_despachos with (security_invoker = on) as
select
  d.id, d.numero, d.fecha, d.cliente_id, d.cliente_nombre, d.nota, d.estado, d.texto_original, d.created_at,
  count(l.id)                       as lineas,
  coalesce(sum(l.cantidad_und), 0)  as unidades,
  coalesce(sum(l.metros), 0)        as metros,
  coalesce(sum(l.valor_total), 0)   as valor_total
from public.despachos d
left join public.despacho_lineas l on l.despacho_id = d.id
group by d.id;

-- -----------------------------------------------------------------------------
-- Función: registrar un despacho completo en una sola transacción.
-- p_lineas = [{"producto_id": "...", "cantidad_und": 120, "largo_m": 2.44, "precio_m": 13000}, ...]
-- Devuelve id y número. Falla si el stock quedaría negativo, salvo p_permitir_negativo.
-- -----------------------------------------------------------------------------
create or replace function public.registrar_despacho(
  p_fecha             date,
  p_cliente_nombre    text,
  p_lineas            jsonb,
  p_cliente_id        uuid default null,
  p_nota              text default null,
  p_texto_original    text default null,
  p_permitir_negativo boolean default false
)
returns table (id uuid, numero bigint)
language plpgsql
security invoker
as $$
declare
  v_despacho_id uuid;
  v_numero      bigint;
  v_linea       jsonb;
  v_orden       int := 0;
  v_producto    public.productos%rowtype;
  v_cantidad    numeric;
  v_largo       numeric;
  v_precio      numeric;
  v_metros      numeric;
  v_saldo       numeric;
begin
  if p_lineas is null or jsonb_array_length(p_lineas) = 0 then
    raise exception 'El despacho no tiene líneas';
  end if;
  if coalesce(trim(p_cliente_nombre), '') = '' then
    raise exception 'El despacho necesita cliente';
  end if;

  insert into public.despachos (fecha, cliente_id, cliente_nombre, nota, texto_original, created_by)
  values (p_fecha, p_cliente_id, trim(p_cliente_nombre), p_nota, p_texto_original, auth.uid())
  returning despachos.id, despachos.numero into v_despacho_id, v_numero;

  for v_linea in select * from jsonb_array_elements(p_lineas) loop
    v_orden := v_orden + 1;
    select * into v_producto from public.productos where productos.id = (v_linea->>'producto_id')::uuid;
    if v_producto.id is null then
      raise exception 'Línea %: producto no existe', v_orden;
    end if;

    v_cantidad := (v_linea->>'cantidad_und')::numeric;
    v_largo    := nullif(v_linea->>'largo_m', '')::numeric;
    v_precio   := coalesce(nullif(v_linea->>'precio_m', '')::numeric, v_producto.precio_m);

    if v_cantidad is null or v_cantidad <= 0 then
      raise exception 'Línea % (%): cantidad inválida', v_orden, v_producto.nombre;
    end if;
    if v_producto.unidad = 'm' and (v_largo is null or v_largo <= 0) then
      raise exception 'Línea % (%): falta el largo en metros', v_orden, v_producto.nombre;
    end if;

    v_metros := case when v_producto.unidad = 'm' then round(v_cantidad * v_largo, 3) else null end;

    insert into public.despacho_lineas (despacho_id, producto_id, cantidad_und, largo_m, metros, precio_m, valor_total, orden)
    values (
      v_despacho_id, v_producto.id, v_cantidad, v_largo, v_metros, v_precio,
      case when v_precio is null then null else round(v_precio * coalesce(v_metros, v_cantidad), 2) end,
      v_orden
    );

    insert into public.movimientos (fecha, tipo, producto_id, cantidad_und, largo_m, despacho_id, created_by)
    values (p_fecha, 'salida', v_producto.id, v_cantidad, v_largo, v_despacho_id, auth.uid());

    if not p_permitir_negativo then
      select s.saldo into v_saldo from public.v_stock s where s.producto_id = v_producto.id;
      if v_saldo < 0 then
        raise exception 'Stock insuficiente de % (quedaría en % %)', v_producto.nombre, v_saldo, v_producto.unidad;
      end if;
    end if;
  end loop;

  return query select v_despacho_id, v_numero;
end $$;

-- Anular un despacho: marca el estado y devuelve el stock con movimientos inversos
-- (no se borra nada: el kardex conserva la salida y su reversión).
create or replace function public.anular_despacho(p_despacho_id uuid, p_motivo text default null)
returns void language plpgsql security invoker as $$
declare
  v_numero bigint;
  r record;
begin
  update public.despachos
     set estado = 'anulado',
         nota   = concat_ws(' · ', nota, 'ANULADO: ' || coalesce(p_motivo, 'sin motivo'))
   where despachos.id = p_despacho_id and estado = 'confirmado'
   returning despachos.numero into v_numero;
  if v_numero is null then
    raise exception 'Despacho no existe o ya estaba anulado';
  end if;
  for r in
    select producto_id, cantidad_und, largo_m
      from public.movimientos
     where despacho_id = p_despacho_id and tipo = 'salida'
  loop
    insert into public.movimientos (fecha, tipo, producto_id, cantidad_und, largo_m, despacho_id, nota, created_by)
    values (current_date, 'ajuste_entrada', r.producto_id, r.cantidad_und, r.largo_m, p_despacho_id,
            'Anulación despacho ' || v_numero, auth.uid());
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Seguridad: solo usuarios con sesión (los crea administración, no hay registro público).
-- -----------------------------------------------------------------------------
alter table public.contadores      enable row level security;
alter table public.productos       enable row level security;
alter table public.clientes        enable row level security;
alter table public.despachos       enable row level security;
alter table public.despacho_lineas enable row level security;
alter table public.cortes          enable row level security;
alter table public.movimientos     enable row level security;

create policy "autenticados todo" on public.contadores      for all to authenticated using (true) with check (true);
create policy "autenticados todo" on public.productos       for all to authenticated using (true) with check (true);
create policy "autenticados todo" on public.clientes        for all to authenticated using (true) with check (true);
create policy "autenticados todo" on public.despachos       for all to authenticated using (true) with check (true);
create policy "autenticados todo" on public.despacho_lineas for all to authenticated using (true) with check (true);
create policy "autenticados todo" on public.cortes          for all to authenticated using (true) with check (true);
create policy "autenticados todo" on public.movimientos     for all to authenticated using (true) with check (true);

-- Permisos explícitos: las tablas creadas por el conector no heredan los grants por defecto de Supabase.
grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public grant execute on functions to authenticated;
grant select on public.v_stock, public.v_stock_por_largo, public.v_kardex, public.v_despachos to authenticated;
-- anon no tiene políticas RLS, así que no ve filas; este revoke es un refuerzo (correrlo en el SQL Editor).
revoke all on all tables in schema public from anon;
