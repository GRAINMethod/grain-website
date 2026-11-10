/* Greenhouse Dashboard live feed.
   No ?org: shows the two sample orgs, labeled "Sample data".
   ?org=<slug>: a client's own dashboard (they must be signed in).
   If the feed is unavailable, the page keeps its built-in example. */
(function () {
  'use strict';
  var D = window.GreenhouseDashboard;
  if (!D || !window.fetch) return;

  var qs = new URLSearchParams(location.search);
  var org = (qs.get('org') || '').toLowerCase().replace(/[^a-z0-9-]/g, '');
  var DEMO = { greenhouse: 'hollow-creek-hvac', orchard: 'ridgeline-home-services' };
  var statusEl = document.querySelector('.status-live');
  var detailEl = document.getElementById('last-updated');
  var noteEl = document.getElementById('sample-note');
  var toggleEl = document.querySelector('.view-toggle-wrap');
  var lastOk = 0, started = false, isDemo = !org;

  function clean(s) { return String(s == null ? '' : s).replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  function cleanRich(s) {
    return String(s == null ? '' : s)
      .replace(/<(\/?)strong>/g, '\u0001$1strong\u0002').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/\u0001(\/?)strong\u0002/g, '<$1strong>');
  }
  function shape(v) {
    if (!v || !Array.isArray(v.kpi) || v.kpi.length !== 4 || !v.engines) return null;
    var out = {
      client: clean(v.client),
      kpi: v.kpi.map(function (k) { return { label: clean(k.label), value: clean(k.value), unit: clean(k.unit), delta: clean(k.delta) }; }),
      engines: {}
    };
    var ok = ['G', 'R', 'A', 'I', 'N'].every(function (e) {
      var x = v.engines[e];
      if (!x || !Array.isArray(x.summary) || !x.chart || !Array.isArray(x.chart.bars) || !Array.isArray(x.activity)) return false;
      var feed = x.activity.map(function (a) {
        return { time: clean(a.time), text: cleanRich(a.text), status: /^(live|qualified|booked)$/.test(a.status) ? a.status : 'live' };
      });
      if (!feed.length) feed = [{ time: '', text: 'Nothing here yet. Activity shows up as it happens.', status: 'live' }];
      out.engines[e] = {
        summary: x.summary.map(function (s) { return { label: clean(s.label), value: clean(s.value), unit: clean(s.unit) }; }),
        chart: { title: clean(x.chart.title), stat: clean(x.chart.stat), bars: x.chart.bars.map(function (n) { return Math.max(0, Number(n) || 0); }) },
        activity: feed
      };
      return true;
    });
    return ok ? out : null;
  }
  function authHeaders() {
    try {
      var raw = localStorage.getItem('grain-auth');
      var tok = raw && JSON.parse(raw).access_token;
      return tok ? { Authorization: 'Bearer ' + tok } : {};
    } catch (e) { return {}; }
  }
  function load(slug, view) {
    return fetch('/api/mc/' + slug, { headers: org ? authHeaders() : {}, cache: 'no-store' })
      .then(function (r) {
        if (r.status === 404 && org && !sessionStorage.getItem('grain-bounced')) {
          sessionStorage.setItem('grain-bounced', '1');      // one trip to sign-in, never a loop
          location.href = '/login?next=' + encodeURIComponent('/dashboard?org=' + org);
          return null;
        }
        return r.ok ? r.json() : null;
      })
      .then(function (j) {
        var v = j && shape(j.view);
        if (!v) return null;
        var key = view || (j.org && j.org.tier === 'greenhouse' ? 'greenhouse' : 'orchard');
        D.set(key, v);
        j._view = key;
        try { sessionStorage.removeItem('grain-bounced'); } catch (e) {}
        return j;
      })
      .catch(function () { return null; });
  }
  function label() {
    if (!lastOk) return;
    var s = Math.max(1, Math.round((Date.now() - lastOk) / 1000));
    if (statusEl) statusEl.textContent = isDemo ? 'Sample data' : 'Live';
    if (detailEl) detailEl.textContent = ' · refreshed ' + (s < 90 ? s + 's' : Math.round(s / 60) + 'm') + ' ago';
  }
  function refresh() {
    var jobs = org ? [load(org, null)] : [load(DEMO.greenhouse, 'greenhouse'), load(DEMO.orchard, 'orchard')];
    return Promise.all(jobs).then(function (res) {
      var first = res[0];
      if (!first) return;
      lastOk = Date.now();
      isDemo = !!(first.org && first.org.is_demo);
      if (!started) {
        started = true;
        D.stopClock();
        setInterval(label, 1000);
        if (org) {
          D.show(first._view);
          if (toggleEl) toggleEl.style.display = 'none';
          if (noteEl && !isDemo) noteEl.style.display = 'none';
        }
      }
      label();
    });
  }
  function nudge() {
    if (document.hidden) return;
    if (!isDemo) { refresh(); return; }
    var slug = org || DEMO[D.current() === 'orchard' ? 'orchard' : 'greenhouse'];
    fetch('/api/mc/' + slug, { method: 'POST' }).catch(function () {}).then(function () { setTimeout(refresh, 1200); });
  }

  refresh();
  setInterval(nudge, 40000);
  document.addEventListener('visibilitychange', function () { if (!document.hidden && lastOk && Date.now() - lastOk > 60000) refresh(); });
})();
