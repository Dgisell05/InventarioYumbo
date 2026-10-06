// Edge Function: interpretar-despacho
// -----------------------------------------------------------------------------
// Recibe el texto que escribe el coordinador ("orden para Yesid Gómez: 120 omegas,
// 160 viguetas y 200 ángulos de 2.44") y devuelve la orden estructurada contra el
// catálogo y la lista de clientes de la base de datos.
//
// Claude PROPONE; la app muestra la vista previa y la persona CONFIRMA. Esta función
// nunca escribe en la base de datos.
//
// Secretos necesarios en Supabase (Project Settings → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   llave creada en https://platform.claude.com
//   SUPABASE_URL y SUPABASE_ANON_KEY los inyecta Supabase automáticamente.
//
// Despliegue:  supabase functions deploy interpretar-despacho
// Llamada:     POST /functions/v1/interpretar-despacho  { "texto": "..." }
//              con el header Authorization: Bearer <jwt del usuario logueado>
// -----------------------------------------------------------------------------

import Anthropic from "npm:@anthropic-ai/sdk";
import { z } from "npm:zod";
import { zodOutputFormat } from "npm:@anthropic-ai/sdk/helpers/zod";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "claude-opus-5-5";

const OrdenSchema = z.object({
  cliente: z.object({
    nombre_detectado: z.string().describe("Nombre del cliente tal como aparece en el texto"),
    cliente_id: z.string().nullable().describe("id del cliente del listado si coincide; null si es nuevo"),
    coincidencia: z.enum(["exacta", "aproximada", "nuevo"]),
  }),
  fecha: z.string().nullable().describe("Fecha YYYY-MM-DD solo si el texto la menciona; si no, null"),
  lineas: z.array(
    z.object({
      producto_codigo: z.string().describe("Código del catálogo. Nunca inventar códigos."),
      cantidad_und: z.number().describe("Cantidad de piezas"),
      largo_m: z.number().nullable().describe("Largo en metros de cada pieza; null si el producto va por unidades"),
      texto_original: z.string().describe("Fragmento del texto que originó esta línea"),
      confianza: z.enum(["alta", "media", "baja"]),
    }),
  ),
  preguntas: z.array(z.string()).describe("Dudas que la persona debe resolver antes de confirmar"),
  nota: z.string().nullable().describe("Observaciones del texto que no son líneas (transportador, placa, horario)"),
});

type Producto = {
  codigo: string;
  nombre: string;
  categoria: string;
  unidad: "m" | "und";
  largo_estandar_m: number | null;
  alias: string[];
};
type Cliente = { id: string; nombre: string };

function instrucciones(productos: Producto[], clientes: Cliente[]) {
  const catalogo = productos
    .map((p) => {
      const largo = p.largo_estandar_m ? `largo estándar ${p.largo_estandar_m} m` : p.unidad === "m" ? "largo variable" : "por unidad";
      const alias = p.alias.length ? ` · alias: ${p.alias.join(", ")}` : "";
      return `${p.codigo} | ${p.nombre} | ${p.categoria} | ${largo}${alias}`;
    })
    .join("\n");
  const lista = clientes.map((c) => `${c.id} | ${c.nombre}`).join("\n");

  return `Eres el asistente de bodega de Supplyzone en Yumbo. Conviertes el texto que escribe el coordinador en una orden de despacho estructurada.

Reglas:
- Usa SOLO códigos del catálogo. Si un producto no está, no inventes un código: deja la línea fuera y agrégalo a "preguntas".
- Color y tipo deben coincidir con el catálogo ("tejas rojas de 6" → TEJ-ARQ-ROJA salvo que diga master o zinc).
- Productos con largo variable necesitan largo_m. Si el texto no da el largo y hay largo estándar, úsalo con confianza "media". Si no hay forma de saberlo, pon la línea con largo_m null y pregunta.
- Productos por unidad llevan largo_m null.
- "de 2.44", "x 6", "6 metros", "de 6" significan el largo en metros. "120 omegas" significa cantidad 120.
- Cliente: compara con el listado ignorando mayúsculas y tildes. Si coincide claramente devuelve su id y "exacta"; si se parece pero no es igual devuelve el id y "aproximada" y pregunta; si no está, cliente_id null y "nuevo".
- No asumas precios ni fechas que el texto no diga.
- Si algo es ambiguo, pregunta en "preguntas" en vez de adivinar. Las preguntas van en español, cortas y concretas.

Catálogo (código | nombre | categoría | largo | alias):
${catalogo}

Clientes (id | nombre):
${lista}`;
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

  try {
    const auth = req.headers.get("Authorization") ?? "";
    if (!auth.startsWith("Bearer ")) return json({ error: "Sin sesión" }, 401);

    const { texto } = (await req.json()) as { texto?: string };
    if (!texto || texto.trim().length < 3) return json({ error: "Escribe la orden" }, 400);

    // Cliente de Supabase con el JWT del usuario: aplica RLS, igual que la app.
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });

    const [{ data: productos, error: e1 }, { data: clientes, error: e2 }] = await Promise.all([
      supabase.from("productos").select("codigo, nombre, categoria, unidad, largo_estandar_m, alias").eq("activo", true).order("codigo"),
      supabase.from("clientes").select("id, nombre").eq("activo", true).order("nombre"),
    ]);
    if (e1 || e2) return json({ error: (e1 ?? e2)!.message }, 500);
    if (!productos?.length) return json({ error: "El catálogo está vacío" }, 400);

    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

    const respuesta = await anthropic.messages.parse({
      model: MODEL,
      max_tokens: 4096,
      output_config: { effort: "medium", format: zodOutputFormat(OrdenSchema) },
      // El catálogo y los clientes cambian poco: se cachean para abaratar cada orden.
      system: [
        {
          type: "text",
          text: instrucciones(productos as Producto[], (clientes ?? []) as Cliente[]),
          cache_control: { type: "ephemeral" },
        },
      ],
      messages: [{ role: "user", content: `Hoy es ${new Date().toISOString().slice(0, 10)}.\n\nOrden:\n${texto}` }],
    });

    if (respuesta.stop_reason === "refusal") {
      return json({ error: "Claude no pudo interpretar este texto. Escribe la orden de otra forma." }, 422);
    }
    const orden = respuesta.parsed_output;
    if (!orden) return json({ error: "Respuesta no válida de Claude, intenta de nuevo" }, 502);

    // Doble verificación: ningún código fuera del catálogo llega a la app.
    const codigos = new Set(productos.map((p) => p.codigo));
    const invalidas = orden.lineas.filter((l) => !codigos.has(l.producto_codigo));
    const lineas = orden.lineas.filter((l) => codigos.has(l.producto_codigo));
    const preguntas = [
      ...orden.preguntas,
      ...invalidas.map((l) => `"${l.texto_original}": no encontré ese producto en el catálogo.`),
    ];

    return json({
      ...orden,
      lineas,
      preguntas,
      uso: { entrada: respuesta.usage.input_tokens, salida: respuesta.usage.output_tokens },
    });
  } catch (err) {
    const mensaje = err instanceof Error ? err.message : String(err);
    return json({ error: mensaje }, 500);
  }
});
