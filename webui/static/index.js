function setplebVPN(userId) {
  fetch("/set_plebVPN", {
    method: "POST",
    body: JSON.stringify({ userId: userId }),
  }).then((_res) => {
    window.location.href = "/pleb-VPN";
  });
}

function refreshplebVPNdata(userId) {
  fetch("/refresh_plebVPN_data", {
    method: "POST",
    body: JSON.stringify({ userId: userId }),
  }).then((_res) => {
    window.location.href = "/";
  });
}
