// Injects repo data (config.yml, devices/*.yml) into index.html and emits install.sh.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import yaml from "js-yaml";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

function load() {
  const cfg = yaml.load(fs.readFileSync(path.join(root, "config.yml"), "utf8"));
  const dir = path.join(root, "devices");
  const devices = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".yml"))
    .sort()
    .map((f) => yaml.load(fs.readFileSync(path.join(dir, f), "utf8")));
  const baseUrl = cfg.base_url.replace(/\/$/, "");
  const versions = (process.env.VERSIONS || cfg.openwrt_version).split(",").filter(Boolean);
  // Packages of disabled feeds (feeds.yml) are not built, so they are not listed either.
  const feeds = yaml.load(fs.readFileSync(path.join(root, "feeds.yml"), "utf8")).feeds;
  const enabled = new Set(feeds.filter((f) => f.enabled !== false).map((f) => f.name));
  cfg.packages = cfg.packages.filter((p) => !p.feed || enabled.has(p.feed));
  return { cfg, devices, baseUrl, versions };
}

const deviceCard = (d) => `<article class="card">
  <span class="tag">${esc(d.vendor)}</span>
  <h3>${esc(d.name)}</h3>
  <dl><dt>Target</dt><dd>${esc(d.target)}/${esc(d.subtarget)}</dd>
  <dt>Arch</dt><dd>${esc(d.arch)}</dd>
  <dt>Profile</dt><dd>${esc(d.profile)}</dd></dl>
</article>`;

const packageRow = (p) =>
  `<tr><td><code>${esc(p.name)}</code></td><td><span class="scope">${esc(p.scope)}</span></td><td>${esc(p.description)}</td></tr>`;

// Built package versions: { "<openwrt>": { "<pkg>": { arch: {...}, target: {...} } } }.
// Produced by scripts/ci/versions.py; absent in local dev, then cells show "–".
function loadBuilt() {
  try {
    return JSON.parse(fs.readFileSync(process.env.VERSIONS_JSON, "utf8"));
  } catch {
    return {};
  }
}

const dash = '<span class="muted">–</span>';

function builtVersion(built, ver, pkg, d) {
  const e = built[ver]?.[pkg.name];
  const v = pkg.scope === "arch" ? e?.arch?.[d.arch] : e?.target?.[`${d.target}/${d.subtarget}`];
  return v;
}

// Table 1: packages x OpenWrt versions. Target-scoped packages can differ per target, so list all distinct values.
function versionMatrix(cfg, devices, versions, built) {
  const cell = (pkg, ver) => {
    const vals = [...new Set(devices.map((d) => builtVersion(built, ver, pkg, d)).filter(Boolean))];
    return vals.length ? vals.map((v) => `<code>${esc(v)}</code>`).join("<br>") : dash;
  };
  const head = versions.map((v) => `<th>${esc(v)}</th>`).join("");
  const rows = cfg.packages
    .map((p) => `<tr><td><code>${esc(p.name)}</code></td>${versions.map((v) => `<td>${cell(p, v)}</td>`).join("")}</tr>`)
    .join("\n");
  return `<table><thead><tr><th>Package</th>${head}</tr></thead><tbody>${rows}</tbody></table>`;
}

// Table 3: devices x packages, one table per OpenWrt version (switched by a <select>).
function deviceMatrix(cfg, devices, versions, built) {
  const select = `<label class="vsel">OpenWrt <select id="dm-select">${versions
    .map((v) => `<option value="${esc(v)}">${esc(v)}</option>`)
    .join("")}</select></label>`;
  const tables = versions
    .map((ver, i) => {
      const head = cfg.packages.map((p) => `<th>${esc(p.name)}</th>`).join("");
      const rows = devices
        .map((d) => {
          const cells = cfg.packages
            .map((p) => {
              const v = builtVersion(built, ver, p, d);
              return `<td>${v ? `<code>${esc(v)}</code>` : dash}</td>`;
            })
            .join("");
          return `<tr><td>${esc(d.name)}<div class="muted small">${esc(d.arch)}</div></td>${cells}</tr>`;
        })
        .join("\n");
      return `<div class="tablewrap dm" data-version="${esc(ver)}"${i ? " hidden" : ""}><table><thead><tr><th>Device</th>${head}</tr></thead><tbody>${rows}</tbody></table></div>`;
    })
    .join("\n");
  return select + "\n" + tables;
}

export default function repoData() {
  const { cfg, devices, baseUrl, versions } = load();
  const built = loadBuilt();
  const vars = {
    REPO_NAME: cfg.repo_name,
    BASE_URL: baseUrl,
    VERSION: cfg.openwrt_version,
    VERSIONS: versions.map((v) => `<span class="chip">OpenWrt ${esc(v)}</span>`).join(""),
    DEVICES: devices.map(deviceCard).join("\n"),
    PACKAGES: cfg.packages.map(packageRow).join("\n"),
    VERSION_MATRIX: versionMatrix(cfg, devices, versions, built),
    DEVICE_MATRIX: deviceMatrix(cfg, devices, versions, built),
  };
  const fill = (text) => text.replace(/\{\{(\w+)\}\}/g, (m, k) => (k in vars ? vars[k] : m));

  return {
    name: "repo-data",
    transformIndexHtml: (html) => fill(html),
    generateBundle() {
      // Custom domain: GitHub Pages reads it from a CNAME file at the branch root.
      const host = new URL(baseUrl).hostname;
      if (!host.endsWith(".github.io")) {
        this.emitFile({ type: "asset", fileName: "CNAME", source: host + "\n" });
      }
      const tpl = fs.readFileSync(path.join(root, "site", "templates", "install.sh.in"), "utf8");
      this.emitFile({ type: "asset", fileName: "install.sh", source: fill(tpl) });
    },
  };
}
