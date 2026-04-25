// =====================================================================
// ADULAM · Configuración de Supabase
// =====================================================================
// Reemplaza los valores con los de tu proyecto Supabase.
// Dashboard → Project Settings → API
// =====================================================================

var SUPABASE_URL  = "https://zxcmqzildrioxnxtbfuk.supabase.co";
var SUPABASE_ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp4Y21xemlsZHJpb3hueHRiZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5ODA1MjgsImV4cCI6MjA5MjU1NjUyOH0.qUntj-V7140o_m285MXsNFDEp6TUe0IKDrQRkALx0fw";

// Cliente Supabase sin opciones auth custom
// La versión CDN de supabase-js no soporta bien la opción lock
var supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

window.adulamClient = supabase;
