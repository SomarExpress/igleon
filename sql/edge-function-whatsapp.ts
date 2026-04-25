// =====================================================================
// ADULAM · Edge Function · Enviar WhatsApp vía BuilderBot
// =====================================================================
// Ruta: supabase/functions/send-whatsapp/index.ts
// Despliegue: supabase functions deploy send-whatsapp
//
// Invocación desde el frontend:
//   await supabase.functions.invoke('send-whatsapp', {
//     body: { telefono: '+504...', mensaje: 'Hola' }
//   });
// =====================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// IMPORTANTE: configurar estas variables en:
// Supabase Dashboard → Project → Edge Functions → Secrets
//   BUILDERBOT_URL = https://tu-builderbot.com/v1/messages
//   BUILDERBOT_TOKEN = tu_token_secreto

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { telefono, mensaje, member_id } = await req.json();

    if (!telefono || !mensaje) {
      return new Response(
        JSON.stringify({ error: "Faltan campos: telefono, mensaje" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const BUILDERBOT_URL   = Deno.env.get("BUILDERBOT_URL");
    const BUILDERBOT_TOKEN = Deno.env.get("BUILDERBOT_TOKEN");

    if (!BUILDERBOT_URL) {
      // Modo simulado: no hay BuilderBot configurado todavía
      return new Response(
        JSON.stringify({
          ok: true,
          simulated: true,
          message: "BuilderBot no configurado. Configura BUILDERBOT_URL en Secrets.",
          payload: { telefono, mensaje }
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Modo real: enviar al endpoint de BuilderBot
    const response = await fetch(BUILDERBOT_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${BUILDERBOT_TOKEN}`
      },
      body: JSON.stringify({ phone: telefono, message: mensaje })
    });

    const result = await response.json();

    return new Response(
      JSON.stringify({ ok: response.ok, result, member_id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
