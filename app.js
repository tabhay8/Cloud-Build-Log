"use strict";

(function () {
  var CONFIG = window.APP_CONFIG || {};
  var API_BASE = CONFIG.API_BASE || "";
  var TIMEOUT = CONFIG.REQUEST_TIMEOUT_MS || 15000;
  var RETRIES = CONFIG.RETRY_ATTEMPTS || 3;

  var grid = document.getElementById("projectGrid");
  var chips = document.getElementById("tagChips");
  var searchInput = document.getElementById("searchInput");
  var resultCount = document.getElementById("resultCount");
  var refreshBtn = document.getElementById("refreshBtn");
  var apiDot = document.getElementById("apiDot");
  var apiStatusText = document.getElementById("apiStatusText");
  var themeToggle = document.getElementById("themeToggle");

  var state = { projects: [], tag: null, search: "", loading: false };

  /* ---------- theme ---------- */
  var savedTheme = null;
  try { savedTheme = localStorage.getItem("theme"); } catch (e) {}
  if (savedTheme) document.documentElement.setAttribute("data-theme", savedTheme);

  themeToggle.addEventListener("click", function () {
    var next = document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    try { localStorage.setItem("theme", next); } catch (e) {}
  });

  /* ---------- helpers ---------- */
  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }

  function parseTags(raw) {
    if (Array.isArray(raw)) return raw.filter(Boolean);
    return String(raw || "").split(",").map(function (t) { return t.trim(); }).filter(Boolean);
  }

  function setApiStatus(kind, text) {
    apiDot.className = "dot" + (kind ? " " + kind : "");
    apiStatusText.textContent = text;
  }

  function delay(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  /* ---------- data ---------- */
  function fetchWithTimeout(url) {
    var controller = new AbortController();
    var timer = setTimeout(function () { controller.abort(); }, TIMEOUT);
    return fetch(url, { signal: controller.signal, headers: { Accept: "application/json" } })
      .finally(function () { clearTimeout(timer); });
  }

  function loadProjects() {
    if (state.loading) return Promise.resolve();
    state.loading = true;
    renderSkeleton();
    setApiStatus("warm", "Contacting API…");

    var url = API_BASE + "/api/projects?limit=200";

    function attempt(n) {
      return fetchWithTimeout(url)
        .then(function (res) {
          if (!res.ok) {
            var err = new Error("HTTP " + res.status);
            err.status = res.status;
            throw err;
          }
          return res.json();
        })
        .then(function (data) {
          // Support either a bare array or an envelope like { projects: [...] }
          state.projects = Array.isArray(data) ? data : (data && data.projects) || [];
          setApiStatus("up", "API connected");
          renderChips();
          render();
        })
        .catch(function (error) {
          // 503 = API up but data source waking (serverless SQL resume) — worth retrying.
          var retryable = error.name === "AbortError" || !error.status || error.status >= 500;
          if (n < RETRIES && retryable) {
            setApiStatus("warm", "Waking data source… attempt " + (n + 1) + " of " + RETRIES);
            return delay(1200 * n).then(function () { return attempt(n + 1); });
          }

          // Retries exhausted (or non-retryable error, e.g. 404 because there's no API yet).
          if (Array.isArray(window.FALLBACK_PROJECTS)) {
            state.projects = window.FALLBACK_PROJECTS;
            setApiStatus("warm", "Showing saved data - live API not connected yet");
            renderChips();
            render();
            return;
          }

          setApiStatus("down", "API unreachable");
          renderError(error);
        });
    }

    return attempt(0).finally(function () {
      state.loading = false;
    });
  }

  /* ---------- rendering ---------- */
  function renderSkeleton() {
    grid.setAttribute("aria-busy", "true");
    var html = "";
    for (var i = 0; i < 6; i++) {
      html +=
        '<article class="card skeleton" aria-hidden="true">' +
        '<div class="card-media"></div>' +
        '<div class="card-body">' +
        '<div class="sk-line w60"></div>' +
        '<div class="sk-line w90"></div>' +
        '<div class="sk-line w40"></div>' +
        "</div></article>";
    }
    grid.innerHTML = html;
    resultCount.textContent = "";
  }

  function renderError(error) {
    grid.innerHTML =
      '<div class="state">' +
      "<h3>Could not load projects</h3>" +
      "<p>The API did not respond successfully. If the database is on the serverless tier it may still be resuming — retrying usually resolves it.</p>" +
      '<p style="font-family:var(--mono);font-size:.8rem;opacity:.7">' + escapeHtml(error.message) + "</p>" +
      '<button class="btn btn-primary" id="retryBtn" type="button">Try again</button>' +
      "</div>";
    var retry = document.getElementById("retryBtn");
    if (retry) retry.addEventListener("click", loadProjects);
  }

  function renderChips() {
    var counts = {};
    state.projects.forEach(function (p) {
      parseTags(p.tags).forEach(function (t) { counts[t] = (counts[t] || 0) + 1; });
    });
    var tags = Object.keys(counts).sort(function (a, b) { return counts[b] - counts[a]; }).slice(0, 12);

    var html = '<button class="chip" data-tag="" aria-pressed="' + (state.tag === null) + '">All</button>';
    tags.forEach(function (t) {
      html += '<button class="chip" data-tag="' + escapeHtml(t) + '" aria-pressed="' +
        (state.tag === t) + '">' + escapeHtml(t) + " <span style=\"opacity:.6\">" + counts[t] + "</span></button>";
    });
    chips.innerHTML = html;

    Array.prototype.forEach.call(chips.querySelectorAll(".chip"), function (btn) {
      btn.addEventListener("click", function () {
        var value = btn.getAttribute("data-tag");
        state.tag = value === "" ? null : value;
        renderChips();
        render();
      });
    });
  }

  function visibleProjects() {
    var term = state.search.trim().toLowerCase();
    return state.projects.filter(function (p) {
      if (state.tag && parseTags(p.tags).indexOf(state.tag) === -1) return false;
      if (!term) return true;
      return (
        String(p.title || "").toLowerCase().indexOf(term) !== -1 ||
        String(p.description || "").toLowerCase().indexOf(term) !== -1 ||
        String(p.tags || "").toLowerCase().indexOf(term) !== -1
      );
    });
  }

  function render() {
    var items = visibleProjects();
    resultCount.textContent = items.length + " of " + state.projects.length + " shown";

    if (items.length === 0) {
      grid.innerHTML =
        '<div class="state"><h3>No matching projects</h3>' +
        "<p>Try a different search term or clear the active filter.</p></div>";
      return;
    }

    grid.innerHTML = items.map(function (p, index) {
      var tags = parseTags(p.tags);
      var initial = escapeHtml(String(p.title || "?").charAt(0).toUpperCase());
      var media = p.imageUrl
        ? '<img src="' + escapeHtml(p.imageUrl) + '" alt="" loading="lazy" onerror="this.remove()" />'
        : '<div class="fallback">' + initial + "</div>";
      var link = p.repoUrl
        ? '<a class="card-link" href="' + escapeHtml(p.repoUrl) + '" target="_blank" rel="noopener noreferrer">' +
          escapeHtml(p.title) + "</a>"
        : "";

      return (
        '<article class="card" style="animation-delay:' + Math.min(index * 45, 400) + 'ms">' +
        '<div class="card-media">' + media + "</div>" +
        '<div class="card-body">' +
        "<h3>" + escapeHtml(p.title) + "</h3>" +
        (p.badge ? '<span class="badge">' + escapeHtml(p.badge) + "</span>" : "") +
        "<p>" + escapeHtml(p.description) + "</p>" +
        '<div class="tag-row">' +
        tags.map(function (t) { return '<span class="tag">' + escapeHtml(t) + "</span>"; }).join("") +
        "</div></div>" + link + "</article>"
      );
    }).join("");
  }

  /* ---------- health probe ---------- */
  function checkHealth() {
    return fetchWithTimeout(API_BASE + "/health")
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(function (body) {
        if (body) {
          document.getElementById("buildMeta").textContent =
            "API v" + (body.version || "?") + " · up " + (body.uptimeSeconds || 0) + "s";
        }
      })
      .catch(function () { /* health is informational only */ });
  }

  /* ---------- events ---------- */
  var searchTimer;
  searchInput.addEventListener("input", function () {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(function () {
      state.search = searchInput.value;
      render();
    }, 180);
  });

  refreshBtn.addEventListener("click", loadProjects);

  loadProjects().then(checkHealth);
})();