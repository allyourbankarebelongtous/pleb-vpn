function delete_plebvpn_conf(userId) {
  if (
    confirm_dialog(
      (message =
        "Are you sure you want to delete your uploaded plebvpn.conf? You will have to upload a new plebvpn.conf file to enable Pleb-VPN.")
    ) == true
  ) {
    fetch("/delete_plebvpn_conf", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      window.location.href = "/pleb-VPN";
    });
  }
}

function setplebVPN_on(userId) {
  if (
    confirm_dialog(
      (message =
        "Use currently uploaded plebvpn.conf file and turn on Pleb-VPN?")
    ) == true
  ) {
    var activateBtn = document.getElementById("activate");
    if (activateBtn !== null) {
      activateBtn.classList.add("d-none");
    }
    var activateLoading = document.getElementById("activate_loading");
    if (activateLoading !== null) {
      activateLoading.classList.remove("d-none");
    }
    fetch("/set_plebVPN", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      var activateBtn = document.getElementById("activate");
      if (activateBtn !== null) {
        activateBtn.classList.remove("d-none");
      }
      var activateLoading = document.getElementById("activate_loading");
      if (activateLoading !== null) {
        activateLoading.classList.add("d-none");
      }
      window.location.href = "/pleb-VPN";
    });
  }
}

function setplebVPN_off(userId) {
  if (
    confirm_dialog((message = "Are you sure you want to turn off Pleb-VPN?")) ==
    true
  ) {
    var deactivateBtn = document.getElementById("deactivate");
    if (deactivateBtn !== null) {
      deactivateBtn.classList.add("d-none");
    }
    var deactivateLoading = document.getElementById("deactivate_loading");
    if (deactivateLoading !== null) {
      deactivateLoading.classList.remove("d-none");
    }
    fetch("/set_plebVPN", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      var deactivateBtn = document.getElementById("deactivate");
      if (deactivateBtn !== null) {
        deactivateBtn.classList.remove("d-none");
      }
      var deactivateLoading = document.getElementById("deactivate_loading");
      if (deactivateLoading !== null) {
        deactivateLoading.classList.add("d-none");
      }
      window.location.href = "/pleb-VPN";
    });
  }
}

function setlndHybrid_on(userId) {
  if (
    confirm_dialog(
      (message =
        "Use currently uploaded plebvpn.conf file and turn on Pleb-VPN?")
    ) == true
  ) {
    var activateBtn = document.getElementById("activate");
    if (activateBtn !== null) {
      activateBtn.classList.add("d-none");
    }
    var activateLoading = document.getElementById("activate_loading");
    if (activateLoading !== null) {
      activateLoading.classList.remove("d-none");
    }
    fetch("/set_lndHybrid", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      var activateBtn = document.getElementById("activate");
      if (activateBtn !== null) {
        activateBtn.classList.remove("d-none");
      }
      var activateLoading = document.getElementById("activate_loading");
      if (activateLoading !== null) {
        activateLoading.classList.add("d-none");
      }
      window.location.href = "/lnd-hybrid";
    });
  }
}

function setlndHybrid_off(userId) {
  if (
    confirm_dialog((message = "Are you sure you want to turn off Pleb-VPN?")) ==
    true
  ) {
    var deactivateBtn = document.getElementById("deactivate");
    if (deactivateBtn !== null) {
      deactivateBtn.classList.add("d-none");
    }
    var deactivateLoading = document.getElementById("deactivate_loading");
    if (deactivateLoading !== null) {
      deactivateLoading.classList.remove("d-none");
    }
    fetch("/set_lndHybrid", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      var deactivateBtn = document.getElementById("deactivate");
      if (deactivateBtn !== null) {
        deactivateBtn.classList.remove("d-none");
      }
      var deactivateLoading = document.getElementById("deactivate_loading");
      if (deactivateLoading !== null) {
        deactivateLoading.classList.add("d-none");
      }
      window.location.href = "/lnd-hybrid";
    });
  }
}

function refreshplebVPNdata(userId) {
  fetch("/refresh_plebVPN_data", {
    method: "POST",
    body: JSON.stringify({ userId: userId }),
  }).then((_res) => {
    window.location.href = "/";
  });
}

/* function updateScripts(userId) {
  fetch("/update_scripts", {
    method: "POST",
    body: JSON.stringify({ userId: userId }),
  }).then((_res) => {
    window.location.href = "/";
  });
} */

function confirm_dialog(message) {
  var result = confirm(message);
  return result;
}
