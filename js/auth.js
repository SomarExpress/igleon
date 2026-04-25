// =====================================================================
// ADULAM · Autenticación v1.4.1
// =====================================================================

var Auth = {
  currentUser: null,
  currentProfile: null,

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
    var r = await supabase.auth.signInWithPassword({ email: email, password: password });
    if (r.error) throw r.error;
    this.currentUser = r.data.user;
    await this.loadProfile();
    return r.data;
  },

  async register(email, password, nombre) {
    var r = await supabase.auth.signUp({
      email: email, password: password,
      options: { data: { nombre: nombre, rol: 'miembro' } }
    });
    if (r.error) throw r.error;
    return r.data;
  },

  async logout() {
    try { await supabase.auth.signOut(); } catch(e) {}
    this.currentUser = null;
    this.currentProfile = null;
    window.location.href = this._loginUrl();
  },

  async getSession() {
    try {
      var r = await supabase.auth.getSession();
      if (r.data && r.data.session) {
        this.currentUser = r.data.session.user;
        await this.loadProfile();
        return r.data.session;
      }
    } catch (e) {
      console.error('[ADULAM] getSession:', e.message);
    }
    return null;
  },

  async loadProfile() {
    if (!this.currentUser) return null;
    try {
      var r = await supabase.from('profiles').select('*').eq('id', this.currentUser.id).single();
      if (r.error) {
        this.currentProfile = {
          id: this.currentUser.id,
          nombre: (this.currentUser.user_metadata && this.currentUser.user_metadata.nombre) || this.currentUser.email.split('@')[0],
          email: this.currentUser.email,
          rol: 'miembro'
        };
        return this.currentProfile;
      }
      this.currentProfile = r.data;
      return r.data;
    } catch (e) {
      this.currentProfile = { id: this.currentUser.id, nombre: this.currentUser.email.split('@')[0], email: this.currentUser.email, rol: 'miembro' };
      return this.currentProfile;
    }
  },

  async requireAuth() {
    var s = await this.getSession();
    if (!s) { window.location.href = this._loginUrl(); return false; }
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
