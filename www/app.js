(function () {
  "use strict";

  var sectionToId = {
    generar: "nav_generar",
    historial: "nav_historial",
    fuentes: "nav_fuentes",
    configuracion: "nav_configuracion"
  };

  function setActiveNavigation(section) {
    document.querySelectorAll(".sidebar-nav .nav-item").forEach(function (item) {
      var active = item.id === sectionToId[section];
      item.classList.toggle("active", active);
      if (active) item.setAttribute("aria-current", "page");
      else item.removeAttribute("aria-current");
    });
    closeSidebar();
  }

  function closeSidebar() {
    var sidebar = document.getElementById("barra_lateral");
    var backdrop = document.getElementById("sidebar_backdrop");
    if (sidebar) sidebar.classList.remove("open");
    if (backdrop) backdrop.classList.remove("open");
    var button = document.getElementById("menu_movil");
    if (button) button.setAttribute("aria-expanded", "false");
  }

  function toggleSidebar() {
    var sidebar = document.getElementById("barra_lateral");
    var backdrop = document.getElementById("sidebar_backdrop");
    if (sidebar) sidebar.classList.toggle("open");
    if (backdrop) backdrop.classList.toggle("open");
    var button = document.getElementById("menu_movil");
    if (button && sidebar) button.setAttribute("aria-expanded", sidebar.classList.contains("open") ? "true" : "false");
  }

  function storedTheme() {
    try {
      return window.localStorage.getItem("reporte-telecom-theme");
    } catch (error) {
      return null;
    }
  }

  function applyTheme(dark) {
    document.body.classList.toggle("theme-dark", dark);
    var control = document.getElementById("tema");
    if (control) {
      control.setAttribute("aria-pressed", dark ? "true" : "false");
      var label = control.querySelector("span");
      if (label) label.textContent = dark ? "Tema claro" : "Tema oscuro";
    }
    try {
      window.localStorage.setItem("reporte-telecom-theme", dark ? "dark" : "light");
    } catch (error) {
      /* El tema sigue funcionando aunque el navegador bloquee el almacenamiento. */
    }
  }

  document.addEventListener("click", function (event) {
    if (event.target.closest("#menu_movil")) {
      toggleSidebar();
      return;
    }
    if (event.target.closest("#sidebar_backdrop")) {
      closeSidebar();
      return;
    }
    if (event.target.closest("#tema")) {
      event.preventDefault();
      applyTheme(!document.body.classList.contains("theme-dark"));
      return;
    }
    var navigation = event.target.closest(".sidebar-nav .nav-item");
    if (navigation) {
      document.querySelectorAll(".sidebar-nav .nav-item").forEach(function (item) {
        var active = item === navigation;
        item.classList.toggle("active", active);
        if (active) item.setAttribute("aria-current", "page");
        else item.removeAttribute("aria-current");
      });
      closeSidebar();
    }
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") closeSidebar();
  });

  document.addEventListener("DOMContentLoaded", function () {
    var preferred = storedTheme();
    var systemDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    applyTheme(preferred === "dark" || (preferred === null && systemDark));
  });

  document.addEventListener("shiny:connected", function () {
    if (window.Shiny && !window.__reporteNavigationHandler) {
      window.Shiny.addCustomMessageHandler("navegacion", function (message) {
        setActiveNavigation(message.seccion);
      });
      window.__reporteNavigationHandler = true;
    }
  });
}());
