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
      (message = "Use the current LND port and enable hybrid mode?")
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
    confirm_dialog(
      (message = "Are you sure you want to disable hybrid mode?")
    ) == true
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

function setWireguard_on(userId) {
  if (
    confirm_dialog(
      (message = "Use the current Wireguard port and enable Wireguard?")
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
    fetch("/set_wireguard", {
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
      window.location.href = "/wireguard";
    });
  }
}

function setWireguard_off(userId) {
  if (
    confirm_dialog(
      (message = "Are you sure you want to turn Wireguard off?")
    ) == true
  ) {
    var deactivateBtn = document.getElementById("deactivate");
    if (deactivateBtn !== null) {
      deactivateBtn.classList.add("d-none");
    }
    var deactivateLoading = document.getElementById("deactivate_loading");
    if (deactivateLoading !== null) {
      deactivateLoading.classList.remove("d-none");
    }
    fetch("/set_wireguard", {
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
      window.location.href = "/wireguard";
    });
  }
}

function delete_wireguard_conf(userId) {
  if (
    confirm_dialog(
      (message =
        "Are you sure you want to delete your existing wireguard IP and config files? You will have to download new config files to connect.")
    ) == true
  ) {
    fetch("/delete_wireguard_conf", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      window.location.href = "/wireguard";
    });
  }
}

function display_qrcode(filename) {
  var image = document.getElementById("qr_image");

  fetch("/wireguard/clientqrcode", {
    method: "POST",
    body: JSON.stringify({ filename: filename }),
  })
    .then((response) => response.json())
    .then((data) => {
      // Set the image source to the base64-encoded image
      image.src = "data:image/png;base64," + data.image;
    });
}

function download_file(filename) {
  // Make an AJAX request to the Flask route
  var xhr = new XMLHttpRequest();
  xhr.open("GET", "/wireguard/download_client?filename=" + filename);
  xhr.responseType = "blob";
  xhr.onload = function () {
    // Create a URL that points to the generated file
    var url = URL.createObjectURL(xhr.response);

    // Create a link with the URL and click it to initiate the download
    var link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };
  xhr.send();
}

function delete_all_payments(userId) {
  if (
    confirm_dialog(
      (message =
        "Are you sure you want to delete all your scheduled payments? This is irreversible!")
    ) == true
  ) {
    fetch("/delete_all_payments", {
      method: "POST",
      body: JSON.stringify({ userId: userId }),
    }).then((_res) => {
      window.location.href = "/payments";
    });
  }
}

function delete_payment(payment_id) {
  if (
    confirm_dialog(
      (message =
        "Are you sure you want to delete this payment? This is irreversible!")
    ) == true
  ) {
    fetch("/delete_payment", {
      method: "POST",
      body: JSON.stringify({ payment_id: payment_id }),
    }).then((_res) => {
      window.location.href = "/payments";
    });
  }
}

function send_payment() {
  if (
    confirm_dialog(
      (message =
        "Are you sure you want to send this payment now? It will still send on its next scheduled time.")
    ) == true
  ) {
    fetch("/send_payment", {
      method: "POST",
      body: JSON.stringify({ payment_id: payment_id }),
    }).then((_res) => {
      window.location.href = "/payments";
    });
  }
}

function edit_payment(payment_id) {
  const paymentInfo = document.getElementById(`payment_info${payment_id}`);
  const paymentEdit = document.getElementById(`payment_edit${payment_id}`);
  if (paymentInfo && paymentEdit) {
    paymentInfo.classList.add("d-none");
    paymentEdit.classList.remove("d-none");
  }
}

function save_edited_payment(payment_id) {
  const paymentInfo = document.getElementById(`payment_info${payment_id}`);
  const paymentEdit = document.getElementById(`payment_edit${payment_id}`);
  const paymentEditForm = document.getElementById(
    `payment_edit_form${payment_id}`
  );
  if (
    confirm_dialog(
      (message = "Are you sure you want to save this edited payment?")
    ) == true
  ) {
    paymentEditForm.submit();
    if (paymentInfo && paymentEdit) {
      paymentInfo.classList.remove("d-none");
      paymentEdit.classList.add("d-none");
    }
  }
}

function cancel_edited_payment(payment_id) {
  const paymentInfo = document.getElementById(`payment_info${payment_id}`);
  const paymentEdit = document.getElementById(`payment_edit${payment_id}`);
  if (paymentInfo && paymentEdit) {
    paymentInfo.classList.remove("d-none");
    paymentEdit.classList.add("d-none");
  }
}

function refreshplebVPNdata(userId) {
  var activateBtn = document.getElementById("activate");
  if (activateBtn !== null) {
    activateBtn.classList.add("d-none");
  }
  var activateLoading = document.getElementById("activate_loading");
  if (activateLoading !== null) {
    activateLoading.classList.remove("d-none");
  }
  fetch("/refresh_plebVPN_data", {
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
