(() => {
  const systemTheme = () => matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";

  const updateButtons = (activeTheme) => {
    document.querySelectorAll("[data-phx-theme]").forEach(btn => {
      btn.setAttribute("aria-pressed", btn.dataset.phxTheme === activeTheme ? "true" : "false");
    });
  };

  const setTheme = (theme) => {
    if (theme === "system") {
      localStorage.removeItem("phx:theme");
      document.documentElement.setAttribute("data-theme", systemTheme());
      document.documentElement.setAttribute("data-theme-source", "system");
    } else {
      localStorage.setItem("phx:theme", theme);
      document.documentElement.setAttribute("data-theme", theme);
      document.documentElement.setAttribute("data-theme-source", "user");
    }
    updateButtons(theme);
  };
  if (!document.documentElement.hasAttribute("data-theme")) {
    setTheme(localStorage.getItem("phx:theme") || "system");
  }
  window.addEventListener("storage", (e) => e.key === "phx:theme" && setTheme(e.newValue || "system"));
  window.addEventListener("phx:set-theme", (e) => setTheme(e.target.dataset.phxTheme));

  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
    if (document.documentElement.getAttribute("data-theme-source") === "system") {
      document.documentElement.setAttribute("data-theme", systemTheme());
    }
  });
})();
