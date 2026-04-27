// =====================================================================
// ADULAM · Autenticación v1.5 (con timeouts y logging)
// =====================================================================

var Auth = {
  currentUser: null,
  currentProfile: null,

  // Helper: promesa con timeout para evitar que la app se cuelgue
  _withTimeout: function(promise, ms, label) {
    ms = ms || 8000;
    label = label || 'operación';
    return new Promise(function(resolve, reject) {
      var timer = setTimeout(function() {
        reject(new Error('Timeout (' + ms + 'ms) en ' + label));
      }, ms);
      promise.then(function(v) {
        clearTimeout(timer);
        resolve(v);
      }).catch(function(e) {
        clearTimeout(timer);
        reject(e);
      });
    });
  },

  _getBase: function() {
    var path = window.location.pathname;
    if (path.indexOf('/pages/') !== -1) {
      return path.substring(0, path.indexOf('/pages/')) + '/';
    }
    return path.substring(0, path.lastIndexOf('/') + 1);
  },

  _loginUrl: function() { return this._getBase() + 'login.html'; },
  _dashboardUrl: function() { return this._getBase() + 'pages/dashboard.html'; },

  async login(email, password) {
    console.log('[Auth] login: iniciando...');
    var r = await this._withTimeout(
      supabase.auth.signInWithPassword({ email: email, password: password }),
      10000, 'signInWithPassword'
    );
    if (r.error) throw r.error;
    this.currentUser = r.data.user;
    console.log('[Auth] login: OK, user.id =', this.currentUser.id);
    try {
      await this._withTimeout(this.loadProfile(), 5000, 'loadProfile');
    } catch (e) {
      console.warn('[Auth] login: loadProfile fallo, usando fallback. Error:', e.message);
      this._setFallbackProfile();
    }
    return r.data;
  },

  async register(email, password, nombre) {
    console.log('[Auth] register: iniciando...');
    var r = await this._withTimeout(
      supabase.auth.signUp({
        email: email, password: password,
        options: { data: { nombre: nombre, rol: 'miembro' } }
      }),
      10000, 'signUp'
    );
    if (r.error) throw r.error;
    return r.data;
  },

  async logout() {
    console.log('[Auth] logout');
    try { await supabase.auth.signOut(); } catch(e) { console.warn('[Auth] signOut error:', e); }
    this.currentUser = null;
    this.currentProfile = null;
    window.location.href = this._loginUrl();
  },

  _setFallbackProfile: function() {
    if (!this.currentUser) return;
    var meta = this.currentUser.user_metadata || {};
    this.currentProfile = {
      id: this.currentUser.id,
      nombre: meta.nombre || (this.currentUser.email ? this.currentUser.email.split('@')[0] : 'Usuario'),
      email: this.currentUser.email,
      rol: 'miembro'
    };
    console.log('[Auth] fallback profile aplicado:', this.currentProfile);
  },

  async getSession() {
    console.log('[Auth] getSession: consultando sesion...');
    try {
      var r = await this._withTimeout(
        supabase.auth.getSession(),
        5000, 'getSession'
      );
      if (r && r.data && r.data.session) {
        this.currentUser = r.data.session.user;
        console.log('[Auth] getSession: sesion activa, user.id =', this.currentUser.id);
        try {
          await this._withTimeout(this.loadProfile(), 5000, 'loadProfile');
        } catch (e) {
          console.warn('[Auth] getSession: loadProfile fallo, usando fallback. Error:', e.message);
          this._setFallbackProfile();
        }
        return r.data.session;
      }
      console.log('[Auth] getSession: sin sesion activa');
    } catch (e) {
      console.error('[Auth] getSession ERROR:', e.message);
    }
    return null;
  },

  async loadProfile() {
    if (!this.currentUser) return null;
    console.log('[Auth] loadProfile: consultando profiles para', this.currentUser.id);
    try {
      var r = await this._withTimeout(
        supabase.from('profiles').select('*').eq('id', this.currentUser.id).maybeSingle(),
        5000, 'profiles.select'
      );
      if (r.error) {
        console.warn('[Auth] loadProfile: error de Supabase:', r.error.message);
        this._setFallbackProfile();
        return this.currentProfile;
      }
      if (!r.data) {
        console.warn('[Auth] loadProfile: usuario sin fila en profiles, usando fallback');
        this._setFallbackProfile();
        return this.currentProfile;
      }
      this.currentProfile = r.data;
      console.log('[Auth] loadProfile: OK, rol =', this.currentProfile.rol);
      return r.data;
    } catch (e) {
      console.error('[Auth] loadProfile EXCEPCION:', e.message);
      this._setFallbackProfile();
      return this.currentProfile;
    }
  },

  async requireAuth() {
    var s = await this.getSession();
    if (!s) {
      console.log('[Auth] requireAuth: no hay sesion, redirigiendo a login');
      window.location.href = this._loginUrl();
      return false;
    }
    if (!this.currentProfile) {
      console.warn('[Auth] requireAuth: sin profile, aplicando fallback');
      this._setFallbackProfile();
    }
    return true;
  },

  hasRole: function(r) {
    if (!this.currentProfile) return false;
    if (!Array.isArray(r)) r = [r];
    return r.includes(this.currentProfile.rol);
  },

  applyRoleVisibility: function() {
    document.querySelectorAll('[data-roles]').forEach(function(el) {
      var roles = el.getAttribute('data-roles').split(',').map(function(r) { return r.trim(); });
      if (!Auth.hasRole(roles)) el.style.display = 'none';
    });
  }
};

window.Auth = Auth;
