-- Catálogo inicial. Sale de lo que realmente se vendió en SALIDAS_SUPPLYZONE.xlsm (832 líneas, 2023-2026).
-- Ajustar nombres, colores y alias en la app (pantalla Catálogo) después de cargar.
-- unidad 'm'  : stock en metros lineales (tejas, perfilería, perlines)
-- unidad 'und': stock en unidades (UPVC comprada en largo fijo, tornillería)

insert into public.productos (codigo, nombre, categoria, tipo, color, unidad, largo_estandar_m, alias) values
-- Tejas aluzinc (fabricadas, se cortan a la medida)
('TEJ-ARQ-AZUL',   'Teja arquitectónica azul',   'TEJAS', 'ARQUITECTONICA', 'AZUL',  'm', null, '{"arquitectonica azul","teja azul","arq azul"}'),
('TEJ-ARQ-ROJA',   'Teja arquitectónica roja',   'TEJAS', 'ARQUITECTONICA', 'ROJA',  'm', null, '{"arquitectonica roja","teja roja","arq roja","rojo"}'),
('TEJ-ARQ-VERDE',  'Teja arquitectónica verde',  'TEJAS', 'ARQUITECTONICA', 'VERDE', 'm', null, '{"arquitectonica verde","teja verde"}'),
('TEJ-ARQ-BLANCA', 'Teja arquitectónica blanca', 'TEJAS', 'ARQUITECTONICA', 'BLANCA','m', null, '{"arquitectonica blanca","teja blanca"}'),
('TEJ-MAS-AZUL',   'Teja master azul',           'TEJAS', 'MASTER',         'AZUL',  'm', null, '{"master azul"}'),
('TEJ-MAS-ROJA',   'Teja master roja',           'TEJAS', 'MASTER',         'ROJA',  'm', null, '{"master roja"}'),
('TEJ-ZINC-AZUL',  'Teja zinc azul',             'TEJAS', 'ZINC',           'AZUL',  'm', null, '{"zinc azul"}'),
('TEJ-ZINC-ROJA',  'Teja zinc roja',             'TEJAS', 'ZINC',           'ROJA',  'm', null, '{"zinc roja"}'),
-- Perfilería liviana (fabricada, largo estándar 2.44 m)
('PERF-OMEGA',     'Omega aluminio',   'PERFILERIA', 'OMEGAS',   'ALUMINIO', 'm', 2.44, '{"omega","omegas"}'),
('PERF-VIGUETA',   'Vigueta aluminio', 'PERFILERIA', 'VIGUETAS', 'ALUMINIO', 'm', 2.44, '{"vigueta","viguetas"}'),
('PERF-ANGULO',    'Ángulo aluminio',  'PERFILERIA', 'ANGULOS',  'ALUMINIO', 'm', 2.44, '{"angulo","angulos","ángulo"}'),
-- Perlines (perfil C en acero). 160*60 según ventas reales; la hoja Productos del Excel decía 160*50.
('PERLIN-120-50-1.5', 'Perlín 120*50*1.5', 'PERLINES', 'PERFIL 120*50*1.5', 'ACERO', 'm', 6, '{"perfil 120x50x1.5","perlin 120 50 1.5"}'),
('PERLIN-120-50-2.0', 'Perlín 120*50*2.0', 'PERLINES', 'PERFIL 120*50*2.0', 'ACERO', 'm', 6, '{"perfil 120x50x2.0","perlin 120 50 2"}'),
('PERLIN-120-50-2.5', 'Perlín 120*50*2.5', 'PERLINES', 'PERFIL 120*50*2.5', 'ACERO', 'm', 6, '{"perfil 120x50x2.5","perlin 120 50 2.5"}'),
('PERLIN-120-50-3.0', 'Perlín 120*50*3.0', 'PERLINES', 'PERFIL 120*50*3.0', 'ACERO', 'm', 6, '{"perfil 120x50x3.0","perlin 120 50 3"}'),
('PERLIN-160-60-1.5', 'Perlín 160*60*1.5', 'PERLINES', 'PERFIL 160*60*1.5', 'ACERO', 'm', 6, '{"perfil 160x60x1.5","perlin 160 60 1.5"}'),
('PERLIN-160-60-2.0', 'Perlín 160*60*2.0', 'PERLINES', 'PERFIL 160*60*2.0', 'ACERO', 'm', 6, '{"perfil 160x60x2.0","perlin 160 60 2"}'),
('PERLIN-160-60-2.5', 'Perlín 160*60*2.5', 'PERLINES', 'PERFIL 160*60*2.5', 'ACERO', 'm', 6, '{"perfil 160x60x2.5","perlin 160 60 2.5"}'),
('PERLIN-160-60-3.0', 'Perlín 160*60*3.0', 'PERLINES', 'PERFIL 160*60*3.0', 'ACERO', 'm', 6, '{"perfil 160x60x3.0","perlin 160 60 3"}'),
('PERLIN-220-80-1.5', 'Perlín 220*80*1.5', 'PERLINES', 'PERFIL 220*80*1.5', 'ACERO', 'm', 6, '{"perfil 220x80x1.5","perlin 220 80 1.5"}'),
('PERLIN-220-80-2.0', 'Perlín 220*80*2.0', 'PERLINES', 'PERFIL 220*80*2.0', 'ACERO', 'm', 6, '{"perfil 220x80x2.0","perlin 220 80 2"}'),
('PERLIN-220-80-2.5', 'Perlín 220*80*2.5', 'PERLINES', 'PERFIL 220*80*2.5', 'ACERO', 'm', 6, '{"perfil 220x80x2.5","perlin 220 80 2.5"}'),
('PERLIN-220-80-3.0', 'Perlín 220*80*3.0', 'PERLINES', 'PERFIL 220*80*3.0', 'ACERO', 'm', 6, '{"perfil 220x80x3.0","perlin 220 80 3"}'),
('PERLIN-305-80-1.5', 'Perlín 305*80*1.5', 'PERLINES', 'PERFIL 305*80*1.5', 'ACERO', 'm', 6, '{"perfil 305x80x1.5","perlin 305 80 1.5"}'),
('PERLIN-305-80-2.0', 'Perlín 305*80*2.0', 'PERLINES', 'PERFIL 305*80*2.0', 'ACERO', 'm', 6, '{"perfil 305x80x2.0","perlin 305 80 2"}'),
('PERLIN-305-80-2.5', 'Perlín 305*80*2.5', 'PERLINES', 'PERFIL 305*80*2.5', 'ACERO', 'm', 6, '{"perfil 305x80x2.5","perlin 305 80 2.5"}'),
('PERLIN-305-80-3.0', 'Perlín 305*80*3.0', 'PERLINES', 'PERFIL 305*80*3.0', 'ACERO', 'm', 6, '{"perfil 305x80x3.0","perlin 305 80 3"}'),
-- Tejas UPVC (compradas, largo fijo 11.8 m; stock en unidades)
('UPVC-COLONIAL-ROJA',      'UPVC colonial roja',        'UPVC', 'COLONIAL',           'ROJA',         'und', 11.8, '{"colonial roja"}'),
('UPVC-CRESTA-ALTA-AZUL',   'UPVC cresta alta azul',     'UPVC', 'CRESTA ALTA',        'AZUL',         'und', 11.8, '{"cresta alta azul"}'),
('UPVC-CRESTA-ALTA-BLANCA', 'UPVC cresta alta blanca',   'UPVC', 'CRESTA ALTA',        'BLANCA',       'und', 11.8, '{"cresta alta blanca"}'),
('UPVC-CRESTA-ALTA-ROJA',   'UPVC cresta alta roja',     'UPVC', 'CRESTA ALTA',        'ROJA',         'und', 11.8, '{"cresta alta roja"}'),
('UPVC-CRESTA-BAJA-AZUL',   'UPVC cresta baja azul',     'UPVC', 'CRESTA BAJA',        'AZUL',         'und', 11.8, '{"cresta baja azul"}'),
('UPVC-CRESTA-BAJA-BLANCA', 'UPVC cresta baja blanca',   'UPVC', 'CRESTA BAJA',        'BLANCA',       'und', 11.8, '{"cresta baja blanca"}'),
('UPVC-CRESTA-BAJA-ROJA',   'UPVC cresta baja roja',     'UPVC', 'CRESTA BAJA',        'ROJA',         'und', 11.8, '{"cresta baja roja"}'),
('UPVC-CABALLETE-ALTA-BLANCA','UPVC caballete alta blanca','UPVC','CABALLETE ALTA',     'BLANCA',       'und', null, '{"caballete alta"}'),
('UPVC-CABALLETE-BAJA',     'UPVC caballete baja',       'UPVC', 'CABALLETE BAJA',     null,           'und', null, '{"caballete baja"}'),
('UPVC-CABALLETE-COLONIAL', 'UPVC caballete colonial',   'UPVC', 'CABALLETE COLONIAL', null,           'und', null, '{"caballete colonial"}'),
('UPVC-LIMATESA',           'UPVC limatesa',             'UPVC', 'LIMATESAS',          null,           'und', null, '{"limatesa","limatesas"}'),
('UPVC-TRASLUCIDA',         'UPVC traslúcida',           'UPVC', 'TRASLUCIDA',         'TRANSPARENTE', 'und', 11.8, '{"traslucida","translucida"}'),
-- Tornillería (comprada; stock en unidades)
('TOR-PERFORANTE', 'Tornillo perforante', 'TORNILLERIA', 'TOR PERFORANTE', null, 'und', null, '{"tornillo","tornillos","perforante"}')
on conflict (codigo) do nothing;
