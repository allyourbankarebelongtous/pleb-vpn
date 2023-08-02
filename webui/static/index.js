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

function send_payment(payment_id) {
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

function refreshVPNdata(userId) {
  var activateBtn = document.getElementById("activate");
  if (activateBtn !== null) {
    activateBtn.classList.add("d-none");
  }
  var activateLoading = document.getElementById("activate_loading");
  if (activateLoading !== null) {
    activateLoading.classList.remove("d-none");
  }
  fetch("/refresh_VPN_data", {
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

function refreshhybriddata(userId) {
  var activateBtn = document.getElementById("activate");
  if (activateBtn !== null) {
    activateBtn.classList.add("d-none");
  }
  var activateLoading = document.getElementById("activate_loading");
  if (activateLoading !== null) {
    activateLoading.classList.remove("d-none");
  }
  fetch("/refresh_hybrid_data", {
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
    window.location.href = "/hybrid";
  });
}

function refreshwireguarddata(userId) {
  var activateBtn = document.getElementById("activate");
  if (activateBtn !== null) {
    activateBtn.classList.add("d-none");
  }
  var activateLoading = document.getElementById("activate_loading");
  if (activateLoading !== null) {
    activateLoading.classList.remove("d-none");
  }
  fetch("/refresh_wireguard_data", {
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

function refreshtorsplittunneldata(userId) {
  var activateBtn = document.getElementById("activate");
  if (activateBtn !== null) {
    activateBtn.classList.add("d-none");
  }
  var activateLoading = document.getElementById("activate_loading");
  if (activateLoading !== null) {
    activateLoading.classList.remove("d-none");
  }
  fetch("/refresh_torsplittunnel_data", {
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
    window.location.href = "/torsplittunnel";
  });
}

function confirm_dialog(message) {
  var result = confirm(message);
  return result;
}
