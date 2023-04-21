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
    document.getElementById("activate").style.display = "none";
    document.getElementById("activate_loading").style.display = "inline-block";
    document.getElementById("deactivate").style.display = "none";
    document.getElementById("deactivate_loading").style.display =
      "inline-block";
    fetch("/set_plebVPN", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      document.getElementById("activate").style.display = "inline-block";
      document.getElementById("activate_loading").style.display = "none";
      document.getElementById("deactivate").style.display = "inline-block";
      document.getElementById("deactivate_loading").style.display = "none";
      window.location.href = "/pleb-VPN";
    });
  }
}

function setplebVPN_off(userId) {
  if (
    confirm_dialog((message = "Are you sure you want to turn off Pleb-VPN?")) ==
    true
  ) {
    document.getElementById("activate").style.display = "none";
    document.getElementById("activate_loading").style.display = "inline-block";
    document.getElementById("deactivate").style.display = "none";
    document.getElementById("deactivate_loading").style.display = fetch(
      "/set_plebVPN",
      {
        method: "POST",
        body: JSON.stringify({ userId: userId }),
      }
    ).then((_res) => {
      document.getElementById("activate").style.display = "inline-block";
      document.getElementById("activate_loading").style.display = "none";
      document.getElementById("deactivate").style.display = "inline-block";
      document.getElementById("deactivate_loading").style.display = "none";
      window.location.href = "/pleb-VPN";
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
