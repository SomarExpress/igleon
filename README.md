# 🕊️ ADULAM · Sistema de Administración Pastoral

MVP funcional para la administración integral de la iglesia ADULAM, construido con **HTML + Tailwind CSS + JavaScript Vanilla + Supabase**. Sin necesidad de instalar Node.js, npm, ni entornos de desarrollo complejos.

---

## 📦 ¿Qué incluye?

**8 módulos funcionales:**
- 🏠 Dashboard con estadísticas en vivo
- 👥 Membresía (con fotos, familia, ministerio)
- 🏡 Familias
- 🎯 Ministerios / Equipos
- ✅ Asistencia (check rápido por culto)
- 📖 Discipulado (progreso visual)
- ⛪ Planificación de servicios (tablero kanban)
- 💰 Tesorería (balance automático)
- 📱 Redes sociales (calendario de contenido)
- 🤖 Automatizaciones preparadas para BuilderBot/WhatsApp

**Sistema de roles:** pastor · líder · servidor · miembro (con RLS en la base de datos).

---

## 🚀 Despliegue en 5 pasos

### Paso 1 · Crear proyecto en Supabase

1. Entra a [supabase.com](https://supabase.com) y crea un proyecto nuevo (gratis).
2. Elige una región cercana (ej. East US).
3. Guarda la contraseña de la base de datos.
4. Espera 2-3 minutos a que termine de crearse.

### Paso 2 · Ejecutar los scripts SQL (en orden)

1. En Supabase, ve al menú lateral → **SQL Editor** → **+ New query**.
2. **Primero:** pega todo el contenido de `sql/schema.sql` y haz clic en **Run**.
3. **Después:** crea OTRA query nueva, pega `sql/schema-patch-v1.1.sql` y haz clic en **Run** (esto agrega Casas de Pan y arregla el bucket de fotos).
4. Deberías ver: "Success. No rows returned" en ambos casos.

> ⚠️ **Si el script del parche falla al crear el bucket de Storage:** ve manualmente a Supabase → **Storage** → **New bucket** → nombre `member-photos` → marca la casilla **Public bucket** → Create. Luego vuelve a ejecutar solo la segunda mitad del parche (las políticas).

### Paso 3 · Obtener las credenciales

1. En Supabase, ve a **Project Settings** (ícono ⚙️) → **API**.
2. Copia los dos valores:
   - **Project URL** (algo como `https://xxxx.supabase.co`)
   - **anon public key** (una cadena larga que empieza con `eyJ...`)

### Paso 4 · Configurar el proyecto

1. Abre el archivo `js/config.js`.
2. Reemplaza los valores:

```javascript
var SUPABASE_URL  = "https://TU-PROYECTO.supabase.co";     // ← tu URL
var SUPABASE_ANON = "eyJhbGciOi...";                        // ← tu anon key
```

3. Guarda el archivo.

### Paso 5 · Desplegar

**Opción A · GitHub Pages (recomendado, gratis):**

1. Crea un repositorio nuevo en GitHub (puede ser privado).
2. Sube todos los archivos del proyecto (interfaz web de GitHub: arrastrar y soltar).
3. En el repo, ve a **Settings** → **Pages**.
4. En *Source*, selecciona **Deploy from a branch** → `main` → `/ (root)`.
5. En 1-2 minutos tu app estará en `https://tuusuario.github.io/nombre-repo/`.

**Opción B · Vercel:**

1. Entra a [vercel.com](https://vercel.com) y haz login con GitHub.
2. Importa el repositorio. Vercel detecta que es un sitio estático.
3. Clic en **Deploy**. Listo.

**Opción C · Abrir local:**

Simplemente abre `index.html` en Chrome. Funciona igual. (Para fotos, necesitas servidor: usa la extensión *Live Server* de VS Code.)

---

## 👤 Crear el primer usuario pastor

1. Abre tu app desplegada.
2. Haz clic en la pestaña **Registrarse** y crea una cuenta con tu correo.
3. Vuelve a Supabase → **SQL Editor** y ejecuta:

```sql
UPDATE profiles SET rol = 'pastor' WHERE email = 'TU_CORREO_AQUI@ejemplo.com';
```

4. Cierra sesión y vuelve a entrar. Ya tienes acceso total.
5. Desde la aplicación, los demás usuarios se registran normal con rol "miembro" y tú les cambias el rol desde Supabase (tabla `profiles`, columna `rol`).

---

## 📁 Estructura del proyecto

```
adulam/
├── index.html              # Entrada (redirige a login o dashboard)
├── login.html              # Inicio de sesión y registro
├── js/
│   ├── config.js           # Credenciales Supabase (EDITAR ESTE)
│   ├── auth.js             # Módulo de autenticación y roles
│   └── ui.js               # Layout, sidebar, toast, modal, utils
├── pages/
│   ├── dashboard.html      # Panel principal con estadísticas
│   ├── members.html        # CRUD de miembros con fotos
│   ├── families.html       # Familias
│   ├── teams.html          # Ministerios/equipos
│   ├── attendance.html     # Toma de asistencia
│   ├── discipleship.html   # Seguimiento de discipulado
│   ├── services.html       # Planificación tipo kanban
│   ├── treasury.html       # Tesorería (solo pastor/líder)
│   ├── social.html         # Calendario de redes sociales
│   └── automations.html    # Panel de automatizaciones
└── sql/
    ├── schema.sql                      # Script completo para Supabase
    └── edge-function-whatsapp.ts       # Función para BuilderBot
```

---

## 🤖 Conectar BuilderBot (futuro)

Cuando tengas BuilderBot listo:

1. Instala Supabase CLI en tu computadora (opcional, puedes saltar este paso y usarlo más tarde).
2. Despliega la Edge Function:

```bash
supabase functions deploy send-whatsapp
```

3. Configura los secretos en Supabase Dashboard → **Edge Functions** → **Secrets**:
   - `BUILDERBOT_URL` = URL del webhook de tu BuilderBot
   - `BUILDERBOT_TOKEN` = token de autenticación

4. Desde cualquier página del sistema puedes invocarla:

```javascript
await supabase.functions.invoke('send-whatsapp', {
  body: { telefono: '+504...', mensaje: 'Hola!' }
});
```

El archivo `sql/edge-function-whatsapp.ts` ya viene listo para usar.

---

## 🔐 Sistema de roles

| Rol | Puede |
|---|---|
| **pastor** | Todo (incluyendo eliminar, tesorería completa, automatizaciones) |
| **líder** | Todo excepto eliminar · ve tesorería · ejecuta automatizaciones |
| **servidor** | Crear y editar miembros, registrar asistencia, contenido |
| **miembro** | Solo ver su dashboard personal |

Los roles se verifican **en la base de datos (RLS)** y también en la interfaz. Ningún usuario puede saltarse las reglas aunque manipule el frontend.

---

## 🎨 Personalización rápida

- **Moneda:** cambia `L` por `$` o `€` en `js/ui.js`, función `UI.dinero()`.
- **Nombre de la iglesia:** edita el texto "ADULAM" en `login.html` y `js/ui.js` (función `renderLayout`).
- **Colores:** el acento principal es `indigo` / `violet`. Busca y reemplaza por cualquier otro color de Tailwind (ej. `emerald`, `rose`, `amber`).
- **Tipos de reunión:** modifica en `sql/schema.sql` el check constraint de `attendance.tipo_reunion`.

---

## 🏢 Hacia SaaS multi-iglesia (futuro)

El esquema ya está preparado:
- Cada tabla tiene `iglesia_id` que apunta a `churches`.
- Para multi-tenant real, agrega un filtro `iglesia_id = get_my_church()` a las políticas RLS.
- El flujo de onboarding crearía una fila en `churches` y asignaría el `iglesia_id` al perfil del pastor.

---

## ❓ Problemas frecuentes

**"Error: permission denied for table X"**
→ Verifica que ejecutaste TODO el script SQL (incluyendo la sección de RLS). Revisa también que tu usuario tenga el rol correcto en `profiles`.

**"Cannot read properties of null"**
→ Normalmente falta `config.js` editado. Verifica que pegaste bien tu URL y anon key.

**No se suben fotos**
→ Verifica que el bucket `member-photos` esté creado (aparece al final del schema.sql). Si no, créalo manualmente: Supabase → **Storage** → **New bucket** → nombre `member-photos` → marcar **Public**.

**GitHub Pages muestra 404**
→ Espera 2-3 minutos después de activar Pages. Asegúrate de que `index.html` esté en la raíz del repo.

---

## 💚 Licencia y créditos

MVP construido para la iglesia ADULAM. Uso libre para cualquier iglesia o asociación pastoral.

**Stack:** Supabase (PostgreSQL + Auth + Storage + Edge Functions) · Tailwind CSS (CDN) · JavaScript vanilla · sin dependencias de build.

---

*"Porque donde están dos o tres congregados en mi nombre, allí estoy yo en medio de ellos." — Mateo 18:20*
