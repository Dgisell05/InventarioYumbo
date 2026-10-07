# Guía paso a paso · Inventario Yumbo

Tiempo estimado: una tarde para los pasos 1 a 5, una semana de pruebas en paralelo con el Excel.

Marcado con **[tú]** lo que solo puede hacer la persona dueña de las cuentas, y con **[Claude]** lo que se puede pedir en una sesión de Claude Code con los conectores de Supabase y Lovable.

> **Estado al 7 de octubre de 2026:** pasos 1, 2, 4.3 y 5 ya están hechos. Proyecto Supabase `inventario-yumbo` (ref `mugfbdzyhjdvlouybngl`), esquema y datos cargados, función `interpretar-despacho` desplegada, app Lovable `Inventario Yumbo` conectada. Pendientes: usuarios (paso 3), secreto `ANTHROPIC_API_KEY` (paso 4.2), conteo físico (paso 6) y pruebas (paso 7).

## Paso 1 · Crear el proyecto en Supabase  [tú o Claude]

1. En https://supabase.com/dashboard, organización actual (plan Pro), **New project**: nombre `inventario-yumbo`, región `us-east-1`, clave de base de datos guardada en un lugar seguro.
2. Esperar a que quede en estado *Active*.

Costo: en el plan Pro, cada proyecto adicional cobra el cómputo más pequeño (alrededor de 10 USD al mes). Alternativa sin costo: pausar o borrar el proyecto de prueba `Noesis` si ya no se usa.

## Paso 2 · Aplicar el esquema y cargar catálogo y clientes  [Claude]

En el SQL Editor del proyecto nuevo (o con el conector), ejecutar en este orden:

1. `supabase/migrations/20261006000000_esquema_inicial.sql`
2. `supabase/seed/01_productos.sql`
3. `supabase/seed/02_clientes.sql`

Verificar: `select count(*) from productos;` debe dar 40 y `select count(*) from clientes;` debe dar 96.

Nota: el conector de Supabase que usa Claude no puede ejecutar `drop`, `delete` ni `revoke` (queda esperando una confirmación que nunca llega). Esas sentencias se corren a mano en el SQL Editor. Para proyectos nuevos, `supabase/todo_en_uno.sql` trae todo en un solo archivo para pegar.

Si quieren que la numeración de despachos empiece en otro número:

```sql
update contadores set valor = 0 where nombre = 'despacho';   -- el siguiente será 1
```

## Paso 3 · Crear los usuarios  [tú]

Authentication → Users → **Add user** → correo y clave para cada persona (coordinador, administración). No hay registro público.

## Paso 4 · Llave de Claude y función de interpretación  [tú + Claude]

1. **[tú]** Crear una llave en https://platform.claude.com → API Keys. Se muestra una sola vez; cópiala.
2. **[tú]** En Supabase: Project Settings → Edge Functions → Secrets → `ANTHROPIC_API_KEY` = la llave. Nunca la pegues en el chat ni en el código.
3. **[Claude]** Desplegar la función `supabase/functions/interpretar-despacho`. Con la CLI de Supabase:

```bash
supabase link --project-ref <ref del proyecto>
supabase functions deploy interpretar-despacho
```

4. Probar desde la terminal con el token de un usuario logueado:

```bash
curl -X POST https://<ref>.supabase.co/functions/v1/interpretar-despacho \
  -H "Authorization: Bearer <jwt>" -H "Content-Type: application/json" \
  -d '{"texto": "orden para yesid gomez, 120 omegas, 160 viguetas y 200 angulos de 2.44"}'
```

Debe devolver `cliente`, `lineas` con códigos del catálogo y `preguntas`.

Costo por orden: unos centavos de dólar. El catálogo va cacheado, así que cada orden paga sobre todo el texto escrito.

## Paso 5 · Construir la interfaz en Lovable  [Claude o tú]

1. En Lovable, **New project**, conectar el proyecto de Supabase `inventario-yumbo` (Settings → Integrations → Supabase).
2. Pegar como primer mensaje el contenido de `docs/lovable-prompt.md`.
3. Revisar las ocho pantallas que describe el prompt. Lo primero que debe funcionar: login, Nueva orden, PDF.

## Paso 6 · Conteo físico e inventario inicial  [tú]

1. Abrir `docs/plantilla-inventario-inicial.csv` en Excel.
2. Por cada producto y largo que haya en bodega, llenar `cantidad_und`. Si hay tejas rojas de 6 m y de 3 m, van en dos filas. Agregar filas con otros largos si hace falta. Borrar las filas que queden vacías.
3. En la app: Entradas → Importar inventario inicial → pegar el CSV.
4. Revisar en Stock que los saldos en metros coincidan con lo contado.

## Paso 7 · Pruebas en paralelo  [ambos]

Durante una semana, registrar cada despacho en la app y en el Excel. Al final comparar:

- Que el consecutivo de la app siga al del Excel sin saltos.
- Que el stock de los tres o cuatro productos más vendidos cuadre con un reconteo rápido.
- Qué textos de órdenes Claude no entendió bien: esos casos se corrigen agregando alias a los productos en Catálogo, no cambiando código.

Cuando cuadre, el Excel pasa a ser solo histórico.

## Paso 8 · WhatsApp (después)

Requiere cuenta de Meta Business, un número que no esté en un WhatsApp personal y aprobación de Meta (varios días). La función `interpretar-despacho` se reutiliza tal cual: solo se agrega una función que reciba el mensaje de WhatsApp, llame a esta y responda la vista previa en el chat.

## Decisiones tomadas por defecto (se pueden cambiar)

| Tema | Decisión | Dónde cambiarla |
|---|---|---|
| Numeración de despachos | Continúa en 307, sin saltos aunque un despacho falle | `update contadores set valor = N-1 where nombre = 'despacho'` |
| Sobrante de un corte | Se da de baja como merma | Trigger `cortes_registrar_movimientos` en la migración |
| UPVC y tornillería | Se venden desde esta bodega y entran por **compra** | Si no aplica, marcar los productos como inactivos |
| Rollos de acero (materia prima) | Fuera del alcance de esta app | Está en la otra app (`yumbo-inventory-flow`) |
| Precios | Opcionales; si el producto tiene `precio_m`, el despacho lo usa | Catálogo |
| Stock negativo | Bloqueado por defecto; se puede forzar con casilla | Parámetro `p_permitir_negativo` |
| Anular un despacho | No borra nada: registra movimientos inversos y el kardex conserva ambos | Función `anular_despacho` |
| Vistas | Respetan la seguridad por filas del usuario que consulta (`security_invoker`) | Migración |
