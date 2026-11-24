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
  function num(n) { n = Number(n); return isFinite(n) ? n : 0; }
  function str(x, max) { return String(x == null ? '' : x).slice(0, max || 300); }
  // Ads we run (inside Generate). Rendered as HTML, so every field is cleaned.
  function shapeAds(a) {
    if (!a || !Array.isArray(a.rows) || !a.rows.length) return null;
    var t = a.total || {};
    return {
      managed: !!a.managed,
      rows: a.rows.slice(0, 8).map(function (r) {
        return { channel: clean(r.channel), spend: clean(r.spend), leads: clean(r.leads), booked: clean(r.booked), per_booked: clean(r.per_booked) };
      }),
      total: { spend: clean(t.spend), leads: clean(t.leads), booked: clean(t.booked), per_booked: clean(t.per_booked), booked_value: clean(t.booked_value) }
    };
  }
  // Almanac (inside Integrate). Rendered as text, never as HTML.
  function shapeAlmanac(a) {
    if (!a || typeof a !== 'object') return null;
    return {
      docs: num(a.docs), updated: str(a.updated, 16), approved_by: str(a.approved_by, 80),
      asked_30: num(a.asked_30), answered_30: num(a.answered_30), waiting: num(a.waiting),
      topics: (Array.isArray(a.topics) ? a.topics : []).slice(0, 8).map(function (t) { return str(t, 40); }),
      suggest: (Array.isArray(a.suggest) ? a.suggest : []).slice(0, 4).map(function (q) { return str(q, 300); }),
      recent: (Array.isArray(a.recent) ? a.recent : []).slice(0, 5).map(function (r) {
        return { q: str(r && r.q, 300), answered: !!(r && r.answered), ago: str(r && r.ago, 8) };
      })
    };
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
      if (e === 'G') { var ads = shapeAds(x.ads); if (ads) out.engines.G.ads = ads; }
      if (e === 'I') { var alm = shapeAlmanac(x.almanac); if (alm) out.engines.I.almanac = alm; }
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
        D.set(key, v, { demo: !!(j.org && j.org.is_demo) });
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

  // Almanac: ask the account on screen. Resolves to the answer, or null when it can't be reached.
  D.ask = function (question) {
    var slug = org || DEMO[D.current() === 'orchard' ? 'orchard' : 'greenhouse'];
    var headers = { 'Content-Type': 'application/json' };
    if (org) { var a = authHeaders(); for (var k in a) headers[k] = a[k]; }
    return fetch('/api/almanac/' + slug, { method: 'POST', headers: headers, body: JSON.stringify({ question: question }), cache: 'no-store' })
      .then(function (r) { return r.ok ? r.json() : null; })
      .catch(function () { return null; });
  };

  refresh();
  setInterval(nudge, 40000);
  document.addEventListener('visibilitychange', function () { if (!document.hidden && lastOk && Date.now() - lastOk > 60000) refresh(); });
})();
