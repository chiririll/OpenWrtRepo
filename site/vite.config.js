import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";
import repoData from "./plugin.js";

// Env: SITE_OUT (output dir), VERSIONS (comma list of published OpenWrt versions).
export default defineConfig({
  root: fileURLToPath(new URL("./src", import.meta.url)),
  publicDir: fileURLToPath(new URL("./public", import.meta.url)),
  base: "./",
  plugins: [repoData()],
  build: {
    outDir: process.env.SITE_OUT || fileURLToPath(new URL("../out", import.meta.url)),
    emptyOutDir: false,
  },
});
