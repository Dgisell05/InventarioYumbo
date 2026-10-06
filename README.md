# Inventario Yumbo

App simple de inventario para la bodega de Supplyzone en Yumbo: entradas (producción, compra, inventario inicial), cortes, y órdenes de salida que el coordinador dicta por texto y Claude convierte en un despacho listo para confirmar e imprimir.

Reemplaza el Excel `SALIDAS_SUPPLYZONE.xlsm`. No lleva trazabilidad por bobina a propósito.

## Qué hay en este repositorio

| Ruta | Qué es |
|---|---|
| `supabase/migrations/20261006000000_esquema_inicial.sql` | Esquema completo: tablas, vistas, triggers, funciones y seguridad. Probado en Postgres 16. |
| `supabase/seed/01_productos.sql` | Catálogo inicial (40 productos sacados del Excel). |
| `supabase/seed/02_clientes.sql` | 96 clientes sacados del Excel. |
| `supabase/functions/interpretar-despacho/index.ts` | Edge Function que llama a Claude y devuelve la orden estructurada. |
| `docs/GUIA.md` | Guía paso a paso para montar todo. |
| `docs/lovable-prompt.md` | Prompt para que Lovable construya la interfaz. |
| `docs/plantilla-inventario-inicial.csv` | Plantilla para el conteo físico. |

## Cómo funciona el inventario

- Un producto es **tipo + color** (teja arquitectónica roja). El largo se registra en cada movimiento.
- Tejas, perfilería y perlines llevan el stock en **metros lineales**. Un corte no cambia el stock; solo el sobrante se da de baja.
- UPVC y tornillería llevan el stock en **unidades**.
- Todo entra y sale por la tabla `movimientos`. El despacho se registra con la función `registrar_despacho`, que valida stock y numera (arranca en 307 para continuar el Excel).
- Claude **propone** la orden a partir del texto; una persona la revisa y **confirma**. Claude nunca escribe en la base de datos.

Pasos de instalación en `docs/GUIA.md`.
