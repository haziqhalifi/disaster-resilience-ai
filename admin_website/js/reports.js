/* ── State ── */
let currentOffset = 0;
const PAGE_SIZE   = 50;
let currentTotal  = 0;
const _cache      = {}; // report id → full report object
const _smsCache   = {}; // report id → sms reply stats (lazy loaded)

/* ── Toast ── */
function showToast(msg, type = 'success') {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.className = `fixed top-4 right-4 z-50 px-5 py-3 rounded-xl shadow-lg text-sm font-semibold transition-all duration-300 ${
    type === 'success' ? 'bg-green-700 text-white' :
    type === 'error'   ? 'bg-red-600 text-white'   :
                         'bg-gray-700 text-white'
  }`;
  el.classList.remove('hidden');
  clearTimeout(el._t);
  el._t = setTimeout(() => el.classList.add('hidden'), 4000);
}

/* ── Confirm modal ── */
let _confirmCb = null;
function showConfirm(msg, cb) {
  document.getElementById('confirm-message').textContent = msg;
  document.getElementById('confirm-modal').style.display = 'flex';
  _confirmCb = cb;
}
document.getElementById('confirm-ok-btn').addEventListener('click', () => {
  document.getElementById('confirm-modal').style.display = 'none';
  if (_confirmCb) { _confirmCb(); _confirmCb = null; }
});
document.getElementById('confirm-cancel-btn').addEventListener('click', () => {
  document.getElementById('confirm-modal').style.display = 'none';
  _confirmCb = null;
});

/* ── Filters ── */
function getFilters() {
  return {
    status: document.getElementById('status-filter').value,
    type:   document.getElementById('type-filter').value,
    search: document.getElementById('search-input').value.trim(),
  };
}

/* ── Stats ── */
async function loadStats() {
  try {
    const s = await api.getStats(getToken());
    if (!s) return;
    document.getElementById('stat-total').textContent     = s.total     ?? 0;
    document.getElementById('stat-pending').textContent   = s.pending   ?? 0;
    document.getElementById('stat-validated').textContent = s.validated ?? 0;
    document.getElementById('stat-rejected').textContent  = s.rejected  ?? 0;
    document.getElementById('stat-resolved').textContent  = s.resolved  ?? 0;
  } catch (_) {}
}

/* ── Load reports — uses overlay so existing rows stay visible ── */
async function loadReports() {
  const loader = document.getElementById('table-loading');
  loader.style.display = 'flex';
  try {
    const data = await api.getReports(getToken(), { ...getFilters(), limit: PAGE_SIZE, offset: currentOffset });
    if (!data) {
      showToast('Session expired — please sign in again.', 'error');
      return;
    }
    currentTotal = data.total ?? 0;
    renderReports(data.reports ?? []);
    updatePagination();
  } catch (err) {
    showToast(err.message || 'Failed to load reports.', 'error');
  } finally {
    document.getElementById('table-loading').style.display = 'none';
  }
}

/* ── Render reports ── */
const TYPE_LABELS = {
  flood: 'Flood', landslide: 'Landslide',
  blocked_road: 'Blocked Road', medical_emergency: 'Medical Emergency',
};

function renderReports(reports) {
  const tbody = document.getElementById('reports-tbody');
  if (!reports.length) {
    tbody.innerHTML = '<tr><td colspan="9" class="text-center py-10 text-gray-400 dark:text-gray-500">No reports found.</td></tr>';
    return;
  }

  tbody.innerHTML = reports.map(r => {
    _cache[r.id] = r; // cache for modal access

    const tLabel = TYPE_LABELS[r.report_type] || r.report_type;
    const date   = new Date(r.created_at).toLocaleDateString('en-MY', { day: 'numeric', month: 'short', year: 'numeric' });
    const desc   = (r.description || '—').slice(0, 55) + ((r.description || '').length > 55 ? '…' : '');
    const vuln   = r.vulnerable_person ? '<span title="Vulnerable person" style="color:#dc2626;font-weight:700;margin-left:4px">⚠</span>' : '';

    // Location: name + coordinates
    const locName   = r.location_name || '—';
    const hasCoords = r.latitude != null && r.longitude != null;
    const coords    = hasCoords
      ? `<span class="rpt-xs">${Number(r.latitude).toFixed(4)}, ${Number(r.longitude).toFixed(4)}</span>`
      : '';

    // Media thumbnails — click to open full viewer modal
    // Backend returns media_urls (array); show up to 3 thumbnails
    let mediaTd = '<span class="rpt-xs" style="padding:0">—</span>';
    const mediaList = r.media_urls && r.media_urls.length > 0 ? r.media_urls
                    : (r.media_url ? [r.media_url] : []);
    if (mediaList.length > 0) {
      const thumbs = mediaList.slice(0, 3).map(url => {
        // Resolve relative paths against the API base URL
        const src = url.startsWith('http') ? url : (API_BASE + url);
        const safeSrc = src.replace(/'/g, "\\'");
        return `<img src="${src}" loading="lazy"
          class="w-12 h-12 object-cover rounded-lg cursor-pointer hover:opacity-75 transition-opacity inline-block mr-1"
          onclick="openMediaModal('${safeSrc}')"
          onerror="this.style.display='none'"
          title="Click to view media" />`;
      }).join('');
      const extra = mediaList.length > 3 ? `<span class="rpt-xs" style="vertical-align:top">+${mediaList.length - 3}</span>` : '';
      mediaTd = thumbs + extra;
    }

    // AI score — AI Check button ONLY for pending (unverified) reports
    // Existing score badge shown for any already-analysed report
    let aiTd = '';
    const score    = r.ai_analysis?.score;
    const aiStatus = r.ai_status;
    if (aiStatus === 'analyzing') {
      aiTd = '<span style="font-size:.7rem;color:#2563eb;background:#dbeafe;padding:2px 8px;border-radius:9999px;animation:pulse 1s infinite">Analyzing…</span>';
    } else if (aiStatus === 'done' && score !== undefined) {
      const cls = score >= 70 ? 'score-hi' : score >= 40 ? 'score-md' : 'score-lo';
      aiTd = `<button class="score-badge ${cls}" onclick="openAiReport('${r.id}')" title="Click to view full AI report">${score}/100</button>`;
    } else if (r.status === 'pending') {
      aiTd = `<button class="btn-a btn-ai" onclick="runAiAnalysis('${r.id}')">🤖 AI Check</button>`;
    } else {
      aiTd = '<span class="rpt-xs" style="padding:0">—</span>';
    }

    // Action buttons
    const canApprove = r.status === 'pending';
    const canReject  = r.status === 'pending';
    const canResolve = r.status === 'validated';

    const actions = [
      canApprove ? `<button class="btn-a btn-approve" onclick="approveReport('${r.id}')">Approve</button>` : '',
      canReject  ? `<button class="btn-a btn-reject"  onclick="openReject('${r.id}')">Reject</button>`    : '',
      canResolve ? `<button class="btn-a btn-resolve" onclick="resolveReport('${r.id}')">Resolve</button>` : '',
      `<button class="btn-a btn-del" onclick="deleteReport('${r.id}')">Delete</button>`,
    ].filter(Boolean).join('');

    // SMS reply pill — shown on validated/resolved reports; lazy loaded
    let smsPill = '';
    if (r.status === 'validated' || r.status === 'resolved') {
      const cached = _smsCache[r.id];
      if (cached) {
        smsPill = _renderSmsPill(r.id, cached);
      } else {
        smsPill = `<span id="sms-pill-${r.id}" class="rpt-xs" style="cursor:pointer;color:#2563eb" onclick="loadSmsPill('${r.id}')">Load replies</span>`;
      }
    }

    return `<tr class="rpt-row">
      <td class="px-4 py-3"><span class="tbadge tbadge-${r.report_type}">${tLabel}</span>${vuln}</td>
      <td class="px-4 py-3" style="max-width:140px">
        <span class="rpt-cell" style="display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${locName}">${locName}</span>
        ${coords}
      </td>
      <td class="px-4 py-3 rpt-muted" style="max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"
        title="${(r.description||'').replace(/"/g,'&quot;')}">${desc}</td>
      <td class="px-4 py-3">
        <span class="sbadge sbadge-${r.status}">${r.status}</span>
        ${smsPill ? `<div style="margin-top:4px">${smsPill}</div>` : ''}
      </td>
      <td class="px-4 py-3 rpt-cell" style="text-align:center;font-weight:600">${r.vouch_count ?? 0}</td>
      <td class="px-4 py-3">${mediaTd}</td>
      <td class="px-4 py-3">${aiTd}</td>
      <td class="px-4 py-3 rpt-xs" style="white-space:nowrap">${date}</td>
      <td class="px-4 py-3"><div style="display:flex;gap:4px;flex-wrap:wrap">${actions}</div></td>
    </tr>`;
  }).join('');
}

/* ── Pagination ── */
function updatePagination() {
  const from = currentTotal > 0 ? currentOffset + 1 : 0;
  const to   = Math.min(currentOffset + PAGE_SIZE, currentTotal);
  document.getElementById('page-info').textContent = currentTotal > 0 ? `${from}–${to} of ${currentTotal}` : 'No reports';
  document.getElementById('prev-btn').disabled = currentOffset === 0;
  document.getElementById('next-btn').disabled = currentOffset + PAGE_SIZE >= currentTotal;
}

/* ── Media viewer modal ── */
function openMediaModal(url) {
  document.getElementById('media-img').src   = url;
  document.getElementById('media-link').href = url;
  document.getElementById('media-modal').style.display = 'flex';
}
function closeMediaModal() {
  document.getElementById('media-modal').style.display = 'none';
  document.getElementById('media-img').src = '';
}

/* ── AI Report modal ── */
function openAiReport(id) {
  const r = _cache[id];
  if (!r) return;

  const a       = r.ai_analysis || {};
  const score   = a.score;
  const rec     = (a.recommendation || '').toLowerCase();
  const recLabel = rec === 'approve' ? '✅ Approve' : rec === 'reject' ? '❌ Reject' : rec === 'monitor' ? '👁 Monitor' : rec || '—';
  const recColor = rec === 'approve' ? '#166534' : rec === 'reject' ? '#991b1b' : '#854d0e';
  const recBg    = rec === 'approve' ? '#dcfce7'  : rec === 'reject' ? '#fee2e2'  : '#fef9c3';
  const barColor = score >= 70 ? '#16a34a' : score >= 40 ? '#d97706' : '#dc2626';
  const reasoning = a.reasoning || 'No reasoning available.';
  const sources   = Array.isArray(a.sources) ? a.sources : [];
  const date = new Date(r.created_at).toLocaleDateString('en-MY', { day: 'numeric', month: 'long', year: 'numeric' });
  const hasCoords = r.latitude != null && r.longitude != null;

  document.getElementById('ai-modal-content').innerHTML = `
    <div style="display:flex;align-items:center;gap:12px;margin-bottom:20px">
      <div style="width:40px;height:40px;background:#f3e8ff;border-radius:12px;display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:1.25rem">🤖</div>
      <div>
        <h3 class="text-gray-800 dark:text-gray-100" style="font-weight:700;font-size:1.05rem">AI Analysis Report</h3>
        <p class="text-gray-500 dark:text-gray-400" style="font-size:.75rem;margin-top:2px">${TYPE_LABELS[r.report_type] || r.report_type} — ${date}</p>
      </div>
    </div>

    <div class="dark:bg-[#0F1A0F]" style="background:rgba(0,0,0,.04);border-radius:12px;padding:16px;margin-bottom:16px">
      <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:8px">
        <span class="text-gray-600 dark:text-gray-300" style="font-size:.8rem;font-weight:600">Confidence Score</span>
        <span style="font-size:1.8rem;font-weight:800;color:${barColor}">${score !== undefined ? score + '/100' : '—'}</span>
      </div>
      ${score !== undefined ? `<div style="background:rgba(0,0,0,.12);border-radius:9999px;height:8px;overflow:hidden">
        <div style="width:${score}%;height:100%;background:${barColor};border-radius:9999px"></div>
      </div>` : ''}
    </div>

    ${rec ? `<div style="background:${recBg};color:${recColor};border-radius:10px;padding:10px 14px;margin-bottom:16px;font-weight:700;font-size:.9rem">
      Recommendation: ${recLabel}
    </div>` : ''}

    <div style="margin-bottom:16px">
      <p class="text-gray-500 dark:text-gray-400" style="font-size:.7rem;font-weight:700;text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px">Analysis</p>
      <p class="text-gray-700 dark:text-gray-300" style="font-size:.875rem;line-height:1.65;white-space:pre-wrap">${reasoning}</p>
    </div>

    ${sources.length ? `<div style="margin-bottom:16px">
      <p class="text-gray-500 dark:text-gray-400" style="font-size:.7rem;font-weight:700;text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px">Sources Checked (${sources.length}/4)</p>
      ${sources.map(s => {
        const labels = {
          search_news:              '📰 News Search (DuckDuckGo)',
          check_weather:            '🌧️ Live Weather (Open-Meteo)',
          check_gov_alerts:         '🏛️ Government Alerts (MetMalaysia)',
          check_community_signals:  '👥 Community Signals (Photo, Description, Nearby Reports)',
        };
        return `<p class="text-gray-600 dark:text-gray-400" style="font-size:.8rem;margin-top:3px">• ${labels[s] || s}</p>`;
      }).join('')}
    </div>` : ''}

    <div style="border-top:1px solid rgba(128,128,128,.15);padding-top:14px;margin-top:4px">
      <p class="text-gray-500 dark:text-gray-400" style="font-size:.7rem;font-weight:700;text-transform:uppercase;letter-spacing:.06em;margin-bottom:10px">Report Details</p>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;font-size:.825rem">
        <div>
          <p class="text-gray-400 dark:text-gray-500" style="font-size:.7rem">Location</p>
          <p class="text-gray-700 dark:text-gray-300" style="font-weight:600">${r.location_name || '—'}</p>
          ${hasCoords ? `<p class="text-gray-400 dark:text-gray-500" style="font-size:.7rem">${Number(r.latitude).toFixed(5)}, ${Number(r.longitude).toFixed(5)}</p>` : ''}
        </div>
        <div>
          <p class="text-gray-400 dark:text-gray-500" style="font-size:.7rem">Status</p>
          <p class="text-gray-700 dark:text-gray-300" style="font-weight:600;text-transform:capitalize">${r.status}</p>
        </div>
        <div style="grid-column:1/-1">
          <p class="text-gray-400 dark:text-gray-500" style="font-size:.7rem">Full Description</p>
          <p class="text-gray-700 dark:text-gray-300">${r.description || '—'}</p>
        </div>
        ${r.vulnerable_person ? '<div style="grid-column:1/-1"><p style="color:#dc2626;font-weight:600;font-size:.8rem">⚠ Vulnerable person involved</p></div>' : ''}
      </div>
    </div>
  `;

  document.getElementById('ai-modal').dataset.reportId = id;
  document.getElementById('ai-modal').style.display = 'flex';
}

function closeAiModal() {
  document.getElementById('ai-modal').style.display = 'none';
}

/* ── PDF print ── */
function printAiReport() {
  const id = document.getElementById('ai-modal').dataset.reportId;
  const r  = _cache[id] || {};
  const score    = r.ai_analysis?.score;
  const barColor = score >= 70 ? '#16a34a' : score >= 40 ? '#d97706' : '#dc2626';

  document.getElementById('print-section').innerHTML = `
    <h1>Resilience AI — Admin Report</h1>
    <p style="color:#6b7280;font-size:.85rem;margin-bottom:20px">Generated ${new Date().toLocaleString('en-MY')}</p>
    <p class="pr-title">Report Type</p><p>${TYPE_LABELS[r.report_type] || r.report_type || '—'}</p>
    <p class="pr-title">Location</p>
    <p>${r.location_name || '—'}${r.latitude ? ` (${Number(r.latitude).toFixed(5)}, ${Number(r.longitude).toFixed(5)})` : ''}</p>
    <p class="pr-title">Description</p><p>${r.description || '—'}</p>
    <p class="pr-title">Status</p><p style="text-transform:capitalize">${r.status || '—'}</p>
    <p class="pr-title">Submitted</p><p>${r.created_at ? new Date(r.created_at).toLocaleString('en-MY') : '—'}</p>
    <p class="pr-title" style="margin-top:24px">AI Confidence Score</p>
    <p class="pr-score" style="color:${barColor}">${score !== undefined ? score + ' / 100' : '—'}</p>
    <div class="pr-bar" style="width:${score || 0}%;background:${barColor};max-width:300px"></div>
    <p class="pr-title">Recommendation</p>
    <p style="font-weight:700;text-transform:capitalize">${r.ai_analysis?.recommendation || '—'}</p>
    <p class="pr-title">Analysis / Reasoning</p>
    <p style="line-height:1.7;white-space:pre-wrap">${r.ai_analysis?.reasoning || 'No analysis available.'}</p>
    ${Array.isArray(r.ai_analysis?.sources) && r.ai_analysis.sources.length
      ? `<p class="pr-title">Sources Checked (${r.ai_analysis.sources.length}/4)</p>${r.ai_analysis.sources.map(s => {
          const labels = {
            search_news:             'News Search (DuckDuckGo)',
            check_weather:           'Live Weather (Open-Meteo)',
            check_gov_alerts:        'Government Alerts (MetMalaysia)',
            check_community_signals: 'Community Signals (Photo, Description, Nearby Reports)',
          };
          return `<p>• ${labels[s] || s}</p>`;
        }).join('')}`
      : ''}
  `;
  window.print();
}

/* ── Actions ── */
async function approveReport(id) {
  const token = getToken();
  const preview = await api.smsPreview(token, id);
  const phoneUsers = preview?.phone_users ?? 0;
  const location   = preview?.location_name ?? 'this area';
  const confirmMsg = phoneUsers > 0
    ? `Approve this report?\n\n${phoneUsers} user(s) near ${location} will receive an emergency SMS.`
    : 'Approve this report? No phone-registered users are nearby — no SMS will be sent.';
  const btnLabel = phoneUsers > 0 ? 'Approve & Send SMS' : 'Approve';

  const okBtn = document.getElementById('confirm-ok-btn');
  const origLabel = okBtn.textContent;
  okBtn.textContent = btnLabel;

  showConfirm(confirmMsg, async () => {
    okBtn.textContent = origLabel;
    try {
      const result = await api.approveReport(token, id);
      const b = result.broadcast || {};
      const msg = (b.sms_sent > 0)
        ? `Approved — ${b.sms_sent} SMS sent to ${b.total_affected} people nearby.`
        : 'Report approved successfully.';
      showToast(msg, 'success');
      loadReports(); loadStats();
    } catch (err) { showToast(err.message, 'error'); }
  });
}

async function resolveReport(id) {
  showConfirm('Mark this report as resolved?', async () => {
    try {
      await api.resolveReport(getToken(), id);
      showToast('Report marked as resolved.', 'success');
      loadReports(); loadStats();
    } catch (err) { showToast(err.message, 'error'); }
  });
}

async function deleteReport(id) {
  showConfirm('Permanently delete this report? This cannot be undone.', async () => {
    try {
      await api.deleteReport(getToken(), id);
      showToast('Report deleted.', 'success');
      loadReports(); loadStats();
    } catch (err) { showToast(err.message, 'error'); }
  });
}

function openReject(id) {
  document.getElementById('reject-report-id').value = id;
  document.getElementById('reject-reason').value    = '';
  document.getElementById('reject-modal').style.display = 'flex';
}
document.getElementById('reject-cancel-btn').addEventListener('click', () => {
  document.getElementById('reject-modal').style.display = 'none';
});
document.getElementById('reject-confirm-btn').addEventListener('click', async () => {
  const id     = document.getElementById('reject-report-id').value;
  const reason = document.getElementById('reject-reason').value.trim();
  if (!reason) { showToast('Please provide a rejection reason.', 'error'); return; }
  try {
    await api.rejectReport(getToken(), id, reason);
    document.getElementById('reject-modal').style.display = 'none';
    showToast('Report rejected.', 'success');
    loadReports(); loadStats();
  } catch (err) { showToast(err.message, 'error'); }
});

/* ── AI Analysis ── */
async function runAiAnalysis(id) {
  // Replace the button with an animated spinner in-row
  const btn = document.querySelector(`button.btn-ai[onclick="runAiAnalysis('${id}')"]`);
  const spinner = `<span id="ai-spin-${id}" style="display:inline-flex;align-items:center;gap:6px;font-size:.75rem;color:#2563eb;background:#dbeafe;padding:3px 10px;border-radius:9999px">
    <svg style="width:12px;height:12px;animation:spin 0.8s linear infinite;flex-shrink:0" viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="10" stroke="#93c5fd" stroke-width="4" opacity=".3"/>
      <path d="M4 12a8 8 0 018-8" stroke="#2563eb" stroke-width="4" stroke-linecap="round"/>
    </svg>Analyzing…</span>`;
  if (btn) btn.outerHTML = spinner;

  try {
    const result = await api.aiAnalyze(getToken(), id);
    const score  = result.analysis?.score ?? '?';
    const rec    = result.analysis?.recommendation ?? '';
    const cls    = score >= 70 ? 'score-hi' : score >= 40 ? 'score-md' : 'score-lo';
    // Swap spinner for result badge immediately (no full reload flash)
    const spinEl = document.getElementById(`ai-spin-${id}`);
    if (spinEl) {
      spinEl.outerHTML = `<button class="score-badge ${cls}" onclick="openAiReport('${id}')" title="Click to view full AI report">${score}/100</button>`;
    }
    showToast(`AI Score: ${score}/100 — ${rec}`, 'success');
    // Reload after a short delay so the badge persists smoothly
    setTimeout(() => loadReports(), 1500);
  } catch (err) {
    const spinEl = document.getElementById(`ai-spin-${id}`);
    if (spinEl) spinEl.outerHTML = `<button class="btn-a btn-ai" onclick="runAiAnalysis('${id}')">🤖 AI Check</button>`;
    showToast(err.message, 'error');
  }
}

/* ── SMS modal ── */
document.getElementById('sms-cancel-btn').addEventListener('click', () => {
  document.getElementById('sms-modal').style.display = 'none';
});
document.getElementById('sms-send-btn').addEventListener('click', async () => {
  const id = document.getElementById('sms-report-id').value;
  document.getElementById('sms-modal').style.display = 'none';
  try {
    const result   = await api.sendSmsAlert(getToken(), id);
    const affected = result.total_affected ?? 0;
    showToast(
      affected === 0
        ? 'No registered users found within 10 km.'
        : `Community alerted — ${result.sms_sent ?? 0} SMS sent to ${affected} people within 10 km.`,
      affected === 0 ? 'info' : 'success'
    );
  } catch (err) { showToast(err.message, 'error'); }
});

/* ── Rescue requests ── */
async function loadRescueRequests() {
  const container = document.getElementById('rescue-list');
  try {
    const requests = await api.getRescueRequests(getToken());
    if (!requests || !requests.length) {
      container.innerHTML = '<p class="text-gray-400 dark:text-gray-500 text-sm text-center py-4">No active rescue requests.</p>';
      document.getElementById('rescue-badge').classList.add('hidden');
      return;
    }
    document.getElementById('rescue-badge').textContent = requests.length;
    document.getElementById('rescue-badge').classList.remove('hidden');
    container.innerHTML = requests.map(r => {
      const time   = r.reply_at ? new Date(r.reply_at).toLocaleString('en-MY') : '—';
      const hasLoc = r.device_latitude != null && r.device_longitude != null;
      const mapsUrl = hasLoc ? `https://www.google.com/maps?q=${r.device_latitude},${r.device_longitude}` : null;
      return `<div class="rescue-item">
        <div style="flex-shrink:0">
          <span style="display:inline-flex;align-items:center;justify-content:center;width:32px;height:32px;border-radius:9999px;background:#dc2626;color:#fff;font-size:.65rem;font-weight:800">SOS</span>
        </div>
        <div style="flex:1;min-width:0">
          <p style="font-size:.875rem;font-weight:600;color:#9f1239">${r.phone_number || '—'}</p>
          <p style="font-size:.75rem;color:#be123c;margin-top:2px">Replied DANGER at ${time}</p>
          ${hasLoc
            ? `<a href="${mapsUrl}" target="_blank" rel="noopener" style="display:inline-flex;align-items:center;gap:4px;font-size:.75rem;color:#2563eb;margin-top:4px;font-weight:600">
                 📍 View on Map (${r.device_latitude.toFixed(4)}, ${r.device_longitude.toFixed(4)})
               </a>`
            : '<p style="font-size:.75rem;color:#9ca3af;margin-top:2px">Location not available</p>'}
        </div>
        <button onclick="acknowledgeRescue('${r.id}')"
          style="flex-shrink:0;padding:4px 10px;background:#dcfce7;color:#166534;border-radius:8px;font-size:.7rem;font-weight:600;cursor:pointer;border:none;white-space:nowrap">
          Dispatched ✓
        </button>
      </div>`;
    }).join('');
  } catch (_) {
    container.innerHTML = '<p class="text-red-400 text-sm text-center py-4">Failed to load rescue requests.</p>';
  }
}

async function acknowledgeRescue(alertId) {
  try {
    await api.acknowledgeRescue(getToken(), alertId);
    showToast('Rescue team dispatched — marked as handled.', 'success');
    loadRescueRequests();
  } catch (err) { showToast(err.message, 'error'); }
}

/* ── Controls ── */
document.getElementById('refresh-btn').addEventListener('click', () => {
  currentOffset = 0;
  loadReports();
  loadStats();
});
document.getElementById('prev-btn').addEventListener('click', () => {
  currentOffset = Math.max(0, currentOffset - PAGE_SIZE);
  loadReports();
});
document.getElementById('next-btn').addEventListener('click', () => {
  currentOffset += PAGE_SIZE;
  loadReports();
});

let _searchTimer;
document.getElementById('search-input').addEventListener('input', () => {
  clearTimeout(_searchTimer);
  _searchTimer = setTimeout(() => { currentOffset = 0; loadReports(); }, 400);
});
document.getElementById('status-filter').addEventListener('change', () => { currentOffset = 0; loadReports(); });
document.getElementById('type-filter').addEventListener('change',  () => { currentOffset = 0; loadReports(); });

/* ── SMS Reply Summary ── */
function _renderSmsPill(id, data) {
  if (!data || data.total_sent === 0) return '';
  const parts = [];
  if (data.safe_count   > 0) parts.push(`<span style="color:#16a34a;font-weight:700">${data.safe_count} safe</span>`);
  if (data.danger_count > 0) parts.push(`<span style="color:#dc2626;font-weight:700">${data.danger_count} danger</span>`);
  if (data.no_reply_count > 0) parts.push(`<span style="color:#9ca3af">${data.no_reply_count} no reply</span>`);
  if (!parts.length) return '';
  return `<span style="font-size:.68rem;cursor:pointer;text-decoration:underline;text-decoration-style:dotted"
    onclick="openSmsRepliesModal('${id}')" title="Click to view all SMS replies">
    ${parts.join(' · ')}
  </span>`;
}

async function loadSmsPill(id) {
  const el = document.getElementById(`sms-pill-${id}`);
  if (el) el.textContent = '…';
  const data = await api.getSmsReplies(getToken(), id);
  if (!data) { if (el) el.textContent = ''; return; }
  _smsCache[id] = data;
  if (el) el.outerHTML = `<div style="margin-top:4px">${_renderSmsPill(id, data)}</div>`;
}

function openSmsRepliesModal(id) {
  const data = _smsCache[id];
  if (!data) return;
  const r = _cache[id] || {};
  const tLabel = TYPE_LABELS[r.report_type] || r.report_type || '';

  const rows = (data.replies || []).map(item => {
    const statusBg    = item.reply_status === 'safe' ? '#dcfce7' : item.reply_status === 'needs_help' ? '#fee2e2' : '#f3f4f6';
    const statusColor = item.reply_status === 'safe' ? '#166534' : item.reply_status === 'needs_help' ? '#991b1b' : '#6b7280';
    const statusLabel = item.reply_status === 'safe' ? 'SAFE' : item.reply_status === 'needs_help' ? 'DANGER' : 'No reply';
    const sentTime  = item.sent_at  ? new Date(item.sent_at).toLocaleString('en-MY')  : '—';
    const replyTime = item.reply_at ? new Date(item.reply_at).toLocaleString('en-MY') : '—';
    const ack = item.rescue_acknowledged
      ? '<span style="font-size:.65rem;background:#dcfce7;color:#166534;padding:1px 6px;border-radius:9999px;margin-left:4px">Dispatched</span>'
      : '';
    return `<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 0;border-bottom:1px solid rgba(128,128,128,.1)">
      <div>
        <p style="font-size:.825rem;font-weight:600;color:inherit">${item.phone_masked}</p>
        <p style="font-size:.7rem;color:#9ca3af;margin-top:2px">Sent: ${sentTime}</p>
        ${item.reply_at ? `<p style="font-size:.7rem;color:#9ca3af">Replied: ${replyTime}</p>` : ''}
      </div>
      <div style="display:flex;align-items:center;gap:6px">
        <span style="font-size:.75rem;font-weight:700;background:${statusBg};color:${statusColor};padding:3px 10px;border-radius:9999px">${statusLabel}</span>
        ${ack}
      </div>
    </div>`;
  }).join('');

  document.getElementById('sms-replies-title').textContent =
    `SMS Replies — ${tLabel} at ${r.location_name || ''}`;
  document.getElementById('sms-replies-summary').innerHTML =
    `<span style="color:#16a34a;font-weight:700">${data.safe_count} safe</span> &nbsp;·&nbsp; ` +
    `<span style="color:#dc2626;font-weight:700">${data.danger_count} danger</span> &nbsp;·&nbsp; ` +
    `<span style="color:#9ca3af">${data.no_reply_count} no reply</span> &nbsp;·&nbsp; ` +
    `<span style="color:inherit">${data.total_sent} total sent</span>`;
  document.getElementById('sms-replies-list').innerHTML = rows ||
    '<p style="text-align:center;color:#9ca3af;font-size:.8rem;padding:16px 0">No SMS alerts found for this report.</p>';
  document.getElementById('sms-replies-modal').style.display = 'flex';
}

document.getElementById('sms-replies-close').addEventListener('click', () => {
  document.getElementById('sms-replies-modal').style.display = 'none';
});

/* ── Initial load — default to pending so admins see what needs action ── */
loadStats();
document.getElementById('status-filter').value = 'pending';
loadReports();
