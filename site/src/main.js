import "./styles/base.css";
import "./styles/hero.css";
import "./styles/install.css";
import "./styles/catalog.css";

document.querySelectorAll("[data-copy]").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const text = document.getElementById(btn.dataset.copy).innerText;
    try {
      await navigator.clipboard.writeText(text);
      btn.textContent = "Copied";
    } catch {
      btn.textContent = "Press Ctrl+C";
    }
    setTimeout(() => (btn.textContent = "Copy"), 1500);
  });
});

const sel = document.getElementById("dm-select");
if (sel) {
  sel.addEventListener("change", () => {
    document.querySelectorAll(".dm").forEach((el) => (el.hidden = el.dataset.version !== sel.value));
  });
}
