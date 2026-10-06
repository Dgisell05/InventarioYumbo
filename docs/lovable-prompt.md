# Prompt para Lovable · Inventario Yumbo (app simple)

Copiar y pegar como primer mensaje al crear el proyecto en Lovable. Antes, conectar el proyecto de Supabase nuevo (Lovable → Settings → Integrations → Supabase) para que el agente lea el esquema real.

---

Construye una app web interna en español llamada **Inventario Yumbo** para la bodega de Supplyzone Construction en Yumbo. Es para pocos usuarios internos (coordinador y administración), se usa desde celular y PC, y debe ser muy simple: pocas pantallas, letra grande, botones claros.

## Base de datos (ya existe en Supabase, no la rediseñes)

Usa el proyecto de Supabase conectado tal como está. Tablas: `productos`, `clientes`, `despachos`, `despacho_lineas`, `cortes`, `movimientos`. Vistas: `v_stock`, `v_stock_por_largo`, `v_kardex`, `v_despachos`. Funciones RPC: `registrar_despacho(p_fecha, p_cliente_nombre, p_lineas, p_cliente_id, p_nota, p_texto_original, p_permitir_negativo)` y `anular_despacho(p_despacho_id, p_motivo)`. Edge Function: `interpretar-despacho` (POST `{ texto }` con el JWT del usuario; responde `{ cliente, fecha, lineas, preguntas, nota }`).

Reglas del modelo que la interfaz debe respetar:

- Un producto es tipo + color. El **largo va en cada movimiento**, no en el producto.
- Productos con `unidad = 'm'` llevan el stock en **metros lineales**; cada línea pide cantidad de piezas y largo en metros, y muestra el total de metros. Productos con `unidad = 'und'` solo piden cantidad.
- **Nunca** insertes directamente en `despachos` ni `despacho_lineas`: usa el RPC `registrar_despacho`, que crea el despacho, sus líneas y los movimientos de salida en una transacción y valida el stock.
- Las entradas (inventario inicial, producción, compra, ajustes, merma) se registran insertando en `movimientos` con el `tipo` correspondiente. Los cortes se registran insertando en `cortes`; la base de datos crea sus movimientos sola.
- El consecutivo del despacho lo asigna la base de datos. Muéstralo con 4 dígitos (0307).

## Autenticación

Supabase Auth con correo y clave. Sin registro público: las cuentas las crea administración en Supabase. Toda la app va detrás del login.

## Pantallas (menú lateral en PC, barra inferior en celular)

1. **Inicio**: tarjetas con stock total por categoría, lista de productos bajo mínimo en rojo (`v_stock.bajo_minimo`), despachos de hoy y accesos directos a "Nueva orden" y "Registrar producción".

2. **Nueva orden** (la pantalla principal):
   - Un cuadro de texto grande con placeholder "Ej: orden para Yesid Gómez, 120 omegas, 160 viguetas y 200 ángulos de 2.44" y botón **Interpretar**.
   - Al interpretar, llama a la Edge Function `interpretar-despacho` y muestra la **vista previa**: cliente detectado (con selector para corregirlo o crearlo), fecha, y una tabla editable de líneas con producto (buscador sobre `productos`), cantidad, largo, metros calculados y stock disponible de ese producto (desde `v_stock`). Las líneas con confianza "baja" o "media" se resaltan en amarillo. Las `preguntas` se muestran arriba de la tabla como avisos que la persona debe resolver.
   - Si una línea supera el stock, mostrar aviso rojo con el saldo actual. Permitir confirmar igual solo si marcan la casilla "Permitir stock negativo" (pasa `p_permitir_negativo = true`).
   - Botón **Confirmar despacho**: llama al RPC `registrar_despacho` pasando `texto_original`. Al terminar, mostrar el número asignado y generar el **PDF** (jsPDF + autotable): encabezado "SUPPLYZONE CONSTRUCTION SAS · Bodega Yumbo", recuadro con "DESPACHO N° 0307" y fecha, cliente, nota, tabla con producto, largo, cantidad, metros, y tres líneas de firma: "Quien despacha", "Transportador / placa", "Quien recibe".
   - También debe poder crearse una orden **sin texto**, agregando líneas a mano en la misma tabla.

3. **Despachos**: historial desde `v_despachos` con buscador por número o cliente, filtro por fechas, ver detalle, descargar PDF de nuevo y **anular** (RPC `anular_despacho`, pide motivo, confirma antes).

4. **Entradas**: formulario con fecha, tipo (Producción / Compra / Inventario inicial / Ajuste), producto, cantidad y largo (solo si el producto va por metros), nota. Guarda en `movimientos`. Permitir agregar varias líneas y guardar todas juntas. Incluir una pestaña **Importar inventario inicial** que acepta pegar un CSV con columnas `codigo,cantidad_und,largo_m` y lo carga como tipo `inicial`.

5. **Cortes**: formulario con producto (solo `unidad = 'm'`), cantidad y largo de origen, cantidad y largo de destino; muestra el sobrante calculado antes de guardar y advierte si el sobrante es mayor a 0 ("se registrará como merma"). Guarda en `cortes`.

6. **Stock**: tabla desde `v_stock` con buscador y filtro por categoría, columnas: producto, saldo (con unidad), mínimo, estado. Al abrir un producto, mostrar su detalle por largo (`v_stock_por_largo`) y su kardex (`v_kardex` filtrado por producto).

7. **Kardex**: `v_kardex` con filtros por producto, tipo y fechas. Botón exportar a CSV.

8. **Catálogo**: CRUD de `productos` (código, nombre, categoría, tipo, color, unidad, largo estándar, precio por metro, stock mínimo, alias como lista de chips, activo) y de `clientes` (nombre, identificación, teléfono, ciudad, activo).

## Estilo

Sobrio e industrial: fondo claro, un color de acento naranja oscuro (#C2410C), tipografía legible, tablas con números alineados a la derecha, formato colombiano (1.234,5). Mensajes de éxito y error con toasts. Todo en español.
