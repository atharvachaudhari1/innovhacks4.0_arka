(function () {
  const header = document.querySelector(".site-header");
  const menuBtn = document.getElementById("menuBtn");
  const navLinks = document.getElementById("navLinks");
  const contrastBtn = document.getElementById("contrastBtn");
  const toast = document.getElementById("toast");
  const form = document.getElementById("newsletter");
  const iosBtn = document.getElementById("iosDownload");

  const savedContrast = localStorage.getItem("fitguru-contrast");
  if (savedContrast === "high") {
    document.documentElement.setAttribute("data-contrast", "high");
    if (contrastBtn) contrastBtn.setAttribute("aria-pressed", "true");
  }

  window.addEventListener("scroll", () => {
    header?.classList.toggle("is-scrolled", window.scrollY > 8);
  });

  menuBtn?.addEventListener("click", () => {
    const open = navLinks.classList.toggle("is-open");
    menuBtn.setAttribute("aria-expanded", String(open));
  });

  navLinks?.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      navLinks.classList.remove("is-open");
      menuBtn?.setAttribute("aria-expanded", "false");
    });
  });

  contrastBtn?.addEventListener("click", () => {
    const on = document.documentElement.getAttribute("data-contrast") === "high";
    if (on) {
      document.documentElement.removeAttribute("data-contrast");
      localStorage.removeItem("fitguru-contrast");
      contrastBtn.setAttribute("aria-pressed", "false");
    } else {
      document.documentElement.setAttribute("data-contrast", "high");
      localStorage.setItem("fitguru-contrast", "high");
      contrastBtn.setAttribute("aria-pressed", "true");
    }
  });

  document.querySelectorAll(".bill-toggle button").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".bill-toggle button").forEach((b) => b.classList.remove("is-active"));
      btn.classList.add("is-active");
      const annual = btn.dataset.bill === "annual";
      document.querySelectorAll(".price").forEach((price) => {
        const value = annual ? price.dataset.annual : price.dataset.monthly;
        const span = price.querySelector("span");
        if (span && value) span.textContent = value;
        const small = price.querySelector("small");
        if (small) small.textContent = annual ? "/ month, billed yearly" : "/ month";
      });
    });
  });

  form?.addEventListener("submit", (event) => {
    event.preventDefault();
    const status = document.getElementById("formStatus");
    if (status) status.textContent = "You are on the list. We will only send product notes.";
    form.reset();
  });

  function showToast(message) {
    if (!toast) return;
    toast.hidden = false;
    toast.textContent = message;
    setTimeout(() => {
      toast.hidden = true;
    }, 3200);
  }

  iosBtn?.addEventListener("click", async (event) => {
    event.preventDefault();
    try {
      const res = await fetch("/download-ios", { method: "GET" });
      if (!res.ok) {
        showToast("iOS package is not in downloads yet. Add FitGuru-iOS.ipa to enable it.");
        return;
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "FitGuru-iOS.ipa";
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      showToast("iOS package is not in downloads yet. Add FitGuru-iOS.ipa to enable it.");
    }
  });

  document.querySelectorAll(".optional-shot img").forEach((img) => {
    const figure = img.closest("figure");
    if (!figure) return;
    figure.hidden = false;
    img.addEventListener("error", () => {
      figure.remove();
      hideEmptyGallery();
    });
    if (img.complete && img.naturalWidth === 0) figure.remove();
  });
  hideEmptyGallery();

  document.querySelectorAll("video[autoplay]").forEach((video) => {
    video.muted = true;
    video.playsInline = true;
    const tryPlay = () => video.play().catch(() => {});
    if (video.readyState >= 2) tryPlay();
    else video.addEventListener("canplay", tryPlay, { once: true });
  });

  function hideEmptyGallery() {
    const grid = document.getElementById("uiGrid");
    if (!grid) return;
    const visible = [...grid.querySelectorAll("figure")].filter((fig) => !fig.hidden);
    grid.hidden = visible.length === 0;
  }
})();
