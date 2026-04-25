// =====================================================================
// ADULAM · Utilidades UI (mobile-first + Lucide icons)
// =====================================================================

var UI = {
  /* Notificación tipo toast */
  toast(mensaje, tipo) {
    tipo = tipo || 'info';
    const colors = {
      success: 'bg-emerald-600',
      error:   'bg-red-600',
      info:    'bg-slate-800',
      warning: 'bg-amber-600'
    };
    const t = document.createElement('div');
    t.className = 'fixed top-4 left-1/2 -translate-x-1/2 z-[60] px-5 py-3 rounded-full text-white text-sm font-medium shadow-2xl ' +
                  (colors[tipo] || colors.info) + ' animate-fade-in max-w-[90vw]';
    t.textContent = mensaje;
    document.body.appendChild(t);
    setTimeout(function(){ t.style.opacity='0'; t.style.transform='translateX(-50%) translateY(-10px)'; }, 2800);
    setTimeout(function(){ t.remove(); }, 3200);
  },

  fecha(f) {
    if (!f) return '-';
    const d = new Date(f);
    return d.toLocaleDateString('es-HN', { day:'2-digit', month:'2-digit', year:'numeric' });
  },

  dinero(n) {
    if (n === null || n === undefined) return 'L 0.00';
    return 'L ' + Number(n).toLocaleString('es-HN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  },

  /* Genera un icono Lucide. Uso: UI.icon('users', 'w-5 h-5') */
  icon(name, classes) {
    classes = classes || 'w-5 h-5';
    return `<i data-lucide="${name}" class="${classes}"></i>`;
  },

  /* Refresca los iconos después de insertar HTML */
  refreshIcons() {
    if (window.lucide) window.lucide.createIcons();
  },

  /* Layout principal con sidebar responsive mobile-first */
  renderLayout(tituloPagina) {
    const rol = Auth.currentProfile ? Auth.currentProfile.rol : 'miembro';
    const nombre = Auth.currentProfile ? Auth.currentProfile.nombre : 'Usuario';

    const menu = [
      { href: 'dashboard.html',    icon: 'layout-dashboard', label: 'Dashboard',      roles: ['pastor','lider','servidor','miembro'] },
      { href: 'members.html',      icon: 'users',            label: 'Membresía',      roles: ['pastor','lider','servidor'] },
      { href: 'families.html',     icon: 'home',             label: 'Familias',       roles: ['pastor','lider','servidor'] },
      { href: 'houses.html',       icon: 'croissant',        label: 'Casas de Pan',   roles: ['pastor','lider','servidor'] },
      { href: 'teams.html',        icon: 'target',           label: 'Ministerios',    roles: ['pastor','lider','servidor'] },
      { href: 'attendance.html',   icon: 'check-square',     label: 'Asistencia',     roles: ['pastor','lider','servidor'] },
      { href: 'discipleship.html', icon: 'book-open',        label: 'Discipulado',    roles: ['pastor','lider','servidor'] },
      { href: 'services.html',     icon: 'calendar-days',    label: 'Servicios',      roles: ['pastor','lider','servidor'] },
      { href: 'treasury.html',     icon: 'wallet',           label: 'Tesorería',      roles: ['pastor','lider'] },
      { href: 'social.html',       icon: 'share-2',          label: 'Redes Sociales', roles: ['pastor','lider','servidor'] },
      { href: 'automations.html',  icon: 'zap',              label: 'Automatización', roles: ['pastor','lider'] }
    ];

    const currentPage = window.location.pathname.split('/').pop();

    const sidebarItems = menu
      .filter(m => m.roles.includes(rol))
      .map(function(m){
        const active = currentPage === m.href;
        const cls = active
          ? 'bg-indigo-600 text-white font-semibold shadow-sm'
          : 'text-slate-700 hover:bg-slate-100';
        return `<a href="${m.href}" class="flex items-center gap-3 px-4 py-3 rounded-xl ${cls} transition" onclick="UI.closeSidebar()">
          <i data-lucide="${m.icon}" class="w-5 h-5 flex-shrink-0"></i>
          <span class="truncate">${m.label}</span>
        </a>`;
      }).join('');

    // Bottom navigation para móvil (accesos rápidos)
    const bottomNav = [
      { href: 'dashboard.html',  icon: 'layout-dashboard', label: 'Inicio' },
      { href: 'members.html',    icon: 'users',            label: 'Miembros' },
      { href: 'attendance.html', icon: 'check-square',     label: 'Asist.' },
      { href: 'services.html',   icon: 'calendar-days',    label: 'Servicios' }
    ].map(m => {
      const active = currentPage === m.href;
      const cls = active ? 'text-indigo-600' : 'text-slate-500';
      return `<a href="${m.href}" class="flex flex-col items-center gap-0.5 flex-1 py-2 ${cls}">
        <i data-lucide="${m.icon}" class="w-5 h-5"></i>
        <span class="text-[10px] font-medium">${m.label}</span>
      </a>`;
    }).join('');

    return `
      <!-- Overlay para móvil -->
      <div id="sidebarOverlay" class="fixed inset-0 bg-black/50 z-30 hidden lg:hidden" onclick="UI.closeSidebar()"></div>

      <!-- Sidebar -->
      <aside id="sidebar" class="fixed lg:sticky top-0 left-0 h-screen w-72 lg:w-64 bg-white border-r border-slate-200 z-40 transform -translate-x-full lg:translate-x-0 transition-transform flex flex-col shadow-xl lg:shadow-none">
        <div class="p-4 border-b border-slate-200 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-600 to-violet-700 flex items-center justify-center text-white font-bold shadow-md">A</div>
            <div>
              <h1 class="font-bold text-slate-800 leading-tight">ADULAM</h1>
              <p class="text-xs text-slate-500">Sistema Pastoral</p>
            </div>
          </div>
          <button class="lg:hidden p-2 rounded-lg hover:bg-slate-100" onclick="UI.closeSidebar()">
            <i data-lucide="x" class="w-5 h-5"></i>
          </button>
        </div>
        <nav class="flex-1 p-3 space-y-1 overflow-y-auto">${sidebarItems}</nav>
        <div class="p-4 border-t border-slate-200">
          <div class="flex items-center gap-3 mb-3">
            <div class="w-10 h-10 rounded-full bg-slate-200 flex items-center justify-center text-slate-600 font-bold flex-shrink-0">
              ${nombre[0].toUpperCase()}
            </div>
            <div class="min-w-0 flex-1">
              <div class="text-sm font-medium text-slate-800 truncate">${nombre}</div>
              <div class="text-xs text-slate-500 capitalize">${rol}</div>
            </div>
          </div>
          <button onclick="Auth.logout()" class="w-full text-sm px-3 py-2.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 font-medium flex items-center justify-center gap-2">
            <i data-lucide="log-out" class="w-4 h-4"></i>
            Cerrar sesión
          </button>
        </div>
      </aside>

      <!-- Contenido principal -->
      <main class="flex-1 min-h-screen pb-20 lg:pb-0 flex flex-col">
        <header class="sticky top-0 z-20 bg-white/95 backdrop-blur border-b border-slate-200 px-4 lg:px-8 py-3 flex items-center justify-between">
          <div class="flex items-center gap-3 min-w-0 flex-1">
            <button class="lg:hidden p-2 -ml-2 rounded-lg hover:bg-slate-100 flex-shrink-0" onclick="UI.openSidebar()">
              <i data-lucide="menu" class="w-6 h-6"></i>
            </button>
            <h2 class="text-lg lg:text-xl font-bold text-slate-800 truncate">${tituloPagina}</h2>
          </div>
          <div class="text-xs sm:text-sm text-slate-500 hidden sm:block">${new Date().toLocaleDateString('es-HN', { weekday:'short', day:'numeric', month:'short' })}</div>
        </header>
        <div id="pageContent" class="flex-1 p-4 lg:p-6 xl:p-8"></div>
      </main>

      <!-- Bottom nav móvil -->
      <nav class="lg:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 flex z-30 shadow-lg">
        ${bottomNav}
      </nav>
    `;
  },

  openSidebar() {
    document.getElementById('sidebar').classList.remove('-translate-x-full');
    document.getElementById('sidebarOverlay').classList.remove('hidden');
    document.body.style.overflow = 'hidden';
  },

  closeSidebar() {
    const s = document.getElementById('sidebar');
    if (s) s.classList.add('-translate-x-full');
    const o = document.getElementById('sidebarOverlay');
    if (o) o.classList.add('hidden');
    document.body.style.overflow = '';
  },

  /* Tarjeta estadística con icono Lucide */
  statCard(iconName, label, value, color) {
    color = color || 'indigo';
    return `
      <div class="bg-white rounded-2xl border border-slate-200 p-4 sm:p-5 hover:shadow-md transition">
        <div class="flex items-start justify-between mb-3">
          <div class="w-10 h-10 rounded-xl bg-${color}-100 text-${color}-600 flex items-center justify-center flex-shrink-0">
            <i data-lucide="${iconName}" class="w-5 h-5"></i>
          </div>
        </div>
        <div class="text-xs font-medium text-slate-500 mb-1">${label}</div>
        <div class="text-2xl sm:text-3xl font-bold text-${color}-700 leading-tight">${value}</div>
      </div>
    `;
  },

  /* Modal responsive: full-screen en móvil, centrado en desktop */
  openModal(id, contenidoHTML) {
    let modal = document.getElementById(id);
    if (!modal) {
      modal = document.createElement('div');
      modal.id = id;
      modal.className = 'fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm';
      document.body.appendChild(modal);
    }
    modal.innerHTML = `
      <div class="bg-white w-full sm:max-w-lg sm:w-[90%] sm:rounded-2xl rounded-t-2xl max-h-[92vh] overflow-y-auto shadow-2xl animate-slide-up">
        ${contenidoHTML}
      </div>
    `;
    modal.onclick = function(e) { if (e.target === modal) UI.closeModal(id); };
    document.body.style.overflow = 'hidden';
    setTimeout(() => UI.refreshIcons(), 50);
  },

  closeModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.remove();
    document.body.style.overflow = '';
  }
};

window.UI = UI;

// Refrescar iconos automáticamente cuando se agrega contenido dinámico
document.addEventListener('DOMContentLoaded', function(){
  if (window.lucide) window.lucide.createIcons();
});

// Observer: refresca iconos cada vez que cambia el DOM
if (typeof MutationObserver !== 'undefined') {
  const observer = new MutationObserver(function(mutations) {
    let needsRefresh = false;
    mutations.forEach(m => {
      m.addedNodes.forEach(n => {
        if (n.nodeType === 1 && (n.querySelector?.('[data-lucide]') || n.hasAttribute?.('data-lucide'))) {
          needsRefresh = true;
        }
      });
    });
    if (needsRefresh && window.lucide) window.lucide.createIcons();
  });
  document.addEventListener('DOMContentLoaded', () => {
    observer.observe(document.body, { childList: true, subtree: true });
  });
}
