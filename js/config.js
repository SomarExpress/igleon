// =====================================================================
// ADULAM · Configuración de Supabase
// =====================================================================
// Reemplaza los valores con los de tu proyecto Supabase.
// Dashboard → Project Settings → API
// =====================================================================

var SUPABASE_URL  = "https://TU-PROYECTO.supabase.co";
var SUPABASE_ANON = "TU-ANON-KEY-AQUI";

// Cliente Supabase sin opciones auth custom
// La versión CDN de supabase-js no soporta bien la opción lock
var supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

window.adulamClient = supabase;
