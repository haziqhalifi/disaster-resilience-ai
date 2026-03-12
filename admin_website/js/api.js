const API_BASE = 'http://localhost:8000';

const api = {
  async login(username, password) {
    const res = await fetch(`${API_BASE}/api/v1/admin/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Login failed');
    }
    return res.json();
  },

  async register(username, password) {
    const res = await fetch(`${API_BASE}/api/v1/admin/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Registration failed');
    }
    return res.json();
  },

  async getStats(token) {
    const res = await fetch(`${API_BASE}/api/v1/admin/stats`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    return res.json();
  },

  async getReports(token, { status = '', type = '', search = '', limit = 50, offset = 0 } = {}) {
    const params = new URLSearchParams({ limit, offset });
    if (status) params.set('report_status', status);
    if (type)   params.set('report_type', type);
    if (search) params.set('search', search);
    const res = await fetch(`${API_BASE}/api/v1/admin/reports?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    return res.json();
  },

  async smsPreview(token, id) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${id}/sms-preview`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return null; }
    if (!res.ok) return null;
    return res.json();
  },

  async approveReport(token, id) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${id}/approve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Failed to approve');
    }
    return res.json();
  },

  async rejectReport(token, id, reason) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${id}/reject`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ reason }),
    });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Failed to reject');
    }
    return res.json();
  },

  async resolveReport(token, id) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${id}/resolve`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Failed to resolve');
    }
    return res.json();
  },

  async deleteReport(token, id) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Failed to delete');
    }
  },

  async sendSmsAlert(token, id) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${id}/send-sms`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Failed to send SMS alert');
    }
    return res.json();
  },

  async getRescueRequests(token) {
    const res = await fetch(`${API_BASE}/api/v1/admin/rescue-requests`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return []; }
    return res.json();
  },

  async getSmsReplies(token, reportId) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${reportId}/sms-replies`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return null; }
    if (!res.ok) return null;
    return res.json();
  },

  async acknowledgeRescue(token, alertId) {
    const res = await fetch(`${API_BASE}/api/v1/admin/rescue-requests/${alertId}/acknowledge`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'Failed to acknowledge');
    }
    return res.json();
  },

  async aiAnalyze(token, id) {
    const res = await fetch(`${API_BASE}/api/v1/admin/reports/${id}/ai-analyze`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 401) { logout(); return; }
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.detail || 'AI analysis failed');
    }
    return res.json();
  },
};
