import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SERVER_SYSTEM_PROMPT = `你是一個香港魚類辨識專家。請根據魚類照片，在用戶提供的候選目錄中選出最匹配的魚種。
只輸出 JSON，不要輸出 markdown 或其他文字。species_id 必須完全複製候選目錄中的 id。
如果無法完全確認，選擇最接近的一種，並在 reasoning 說明未能完全確認。
JSON 格式：{"species_id":"fish-xxx","confidence":0.0,"reasoning":"簡短理由","alternatives":[{"species_id":"fish-yyy","confidence":0.0,"reason":"理由"}]}`;

// The bundled catalog currently uses fish-001 through fish-153. The server
// boundary keeps this range explicit so a client cannot authorize new ids.
const GAME_SPECIES_ID_PATTERN = /^fish-(?:00[1-9]|0[1-9][0-9]|1[0-4][0-9]|15[0-3])$/;

type SpeciesHint = {
  id: string;
  name: string;
  scientific_name?: string;
};

function parseSpeciesCatalog(value: unknown): SpeciesHint[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > 153) {
    throw new Error("Invalid species catalog");
  }

  const unique = new Map<string, SpeciesHint>();
  for (const item of value) {
    if (!item || typeof item !== "object") continue;
    const candidate = item as Record<string, unknown>;
    const id = candidate.id;
    const name = candidate.name;
    if (
      typeof id !== "string" ||
      !GAME_SPECIES_ID_PATTERN.test(id) ||
      typeof name !== "string" ||
      name.trim().length === 0 ||
      name.length > 120
    ) {
      continue;
    }
    const scientificName = candidate.scientific_name;
    unique.set(id, {
      id,
      name: name.trim(),
      ...(typeof scientificName === "string" && scientificName.length <= 160
        ? { scientific_name: scientificName.trim() }
        : {}),
    });
  }

  if (unique.size === 0) throw new Error("Invalid species catalog");
  return [...unique.values()];
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const vectorEngineKey = Deno.env.get("VECTOR_ENGINE_API_KEY");
  if (!supabaseUrl || !supabaseAnonKey || !vectorEngineKey) {
    return json({ error: "Recognition service is not configured" }, 503);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return json({ error: "Invalid session" }, 401);

  let body: { image_base64?: unknown; species_catalog?: unknown };
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const imageBase64 = body.image_base64;
  if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
    return json({ error: "image_base64 is required" }, 400);
  }
  if (imageBase64.length > 12_000_000) {
    return json({ error: "Image is too large" }, 413);
  }
  let speciesCatalog: SpeciesHint[];
  try {
    speciesCatalog = parseSpeciesCatalog(body.species_catalog);
  } catch (_) {
    return json({ error: "Invalid species catalog" }, 400);
  }
  const allowedSpeciesIds = new Set(speciesCatalog.map((species) => species.id));
  const catalogText = speciesCatalog
    .map((species) =>
      `${species.id}: ${species.name}${species.scientific_name ? ` (${species.scientific_name})` : ""}`,
    )
    .join("\n");

  const baseUrl = Deno.env.get("VECTOR_ENGINE_BASE_URL") ?? "https://api.vectorengine.cn";
  const endpoint = `${baseUrl.replace(/\/$/, "")}/v1/chat/completions`;
  const upstream = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${vectorEngineKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "qvq-max",
      messages: [
        { role: "system", content: SERVER_SYSTEM_PROMPT },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: `請辨識這張魚類照片。只可使用以下候選目錄：\n${catalogText}`,
            },
            {
              type: "image_url",
              image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
            },
          ],
        },
      ],
      max_tokens: 1024,
      temperature: 0.3,
    }),
  });

  if (!upstream.ok) {
    return json({ error: "Recognition provider failed" }, 502);
  }

  const providerData = await upstream.json();
  const content = providerData?.choices?.[0]?.message?.content;
  if (typeof content !== "string") return json({ error: "Invalid provider response" }, 502);

  const start = content.indexOf("{");
  const end = content.lastIndexOf("}");
  if (start < 0 || end <= start) return json({ error: "Invalid provider JSON" }, 502);

  try {
    const parsed = JSON.parse(content.slice(start, end + 1));
    const speciesId = parsed?.species_id;
    if (typeof speciesId !== "string") return json({ error: "Missing species id" }, 502);
    if (!allowedSpeciesIds.has(speciesId)) {
      return json({ error: "Species is not in the authorized catalog" }, 502);
    }

    const alternatives = Array.isArray(parsed.alternatives)
      ? parsed.alternatives.filter(
          (alternative: unknown) =>
            alternative &&
            typeof alternative === "object" &&
            typeof (alternative as Record<string, unknown>).species_id === "string" &&
            allowedSpeciesIds.has(
              (alternative as Record<string, unknown>).species_id as string,
            ),
        )
      : [];
    return json({ ...parsed, alternatives });
  } catch (_) {
    return json({ error: "Invalid provider JSON" }, 502);
  }
});
