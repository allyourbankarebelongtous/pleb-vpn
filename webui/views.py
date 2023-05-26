from flask import Blueprint, render_template, request, flash, jsonify, redirect, url_for, session, send_file
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
from socket_io import socketio
from plebvpn_common import config
from datetime import datetime
from .models import User
from . import db
import json, os, subprocess, time, pexpect, random, qrcode, io, base64, shutil, re, socket, requests

views = Blueprint('views', __name__)

# define variables
ALLOWED_EXTENSIONS = {'conf'}
if os.path.exists('/mnt/hdd/mynode/'):
    HOME_DIR = str('/mnt/hdd/mynode/pleb-vpn')
    EXEC_DIR = str('/opt/mynode/pleb-vpn')
if os.path.exists('/mnt/hdd/raspiblitz.conf'):
    HOME_DIR = str('/mnt/hdd/app-data/pleb-vpn')
    EXEC_DIR = str('/home/admin/pleb-vpn')
PLEBVPN_CONF_UPLOAD_FOLDER = os.path.join(HOME_DIR, 'openvpn')
conf_file_location = os.path.join(HOME_DIR, 'pleb-vpn.conf')
conf_file = config.PlebConfig(conf_file_location)
plebVPN_status = {}
lnd_hybrid_status = {}
cln_hybrid_status = {}
wireguard_status = {}
torsplittunnel_status = {}
torsplittunnel_test_status = {}
update_available = False
enter_input = False

########################
### Home Page routes ###
########################

# home page
@views.route('/', methods=['GET', 'POST'])
@login_required
def home():
    # determine whether LND, CLN, or both node implementations are available
    lnd = False
    cln = False
    lndpath = os.path.join('/etc/systemd/system', 'lnd.service')
    clnpath = os.path.join('/etc/systemd/system', 'lightningd.service')
    if os.path.exists(lndpath):
        lnd = True
    if os.path.exists(clnpath):
        cln = True
    if plebVPN_status == {}:
        get_plebVPN_status()
    if lnd:
        if lnd_hybrid_status == {}:
            get_lnd_hybrid_status()
    if cln:
        if cln_hybrid_status == {}:
            get_cln_hybrid_status()
    if wireguard_status == {}:
        get_wireguard_status()
    message = request.args.get('message') # for when activiating a script with SocketIO, to flash messages after redirecting to home page
    category = request.args.get('category') # for when activiating a script with SocketIO, to flash messages after redirecting to home page
    if message is not None:
        print('flashing message: ', message) # for debug purposes only
        flash(message, category=category)
    return render_template("home.html", 
                           user=current_user, 
                           setting=get_conf(), 
                           plebVPN_status=plebVPN_status, 
                           lnd_hybrid_status=lnd_hybrid_status,
                           cln_hybrid_status=cln_hybrid_status,
                           wireguard_status=wireguard_status,
                           lnd=lnd,
                           cln=cln,
                           update_available=update_available)

# home page data refresh
@views.route('/refresh_plebVPN_data', methods=['POST'])
@login_required
def refresh_plebVPN_data():
    # refresh pleb-vpn status of connection to vps
    get_plebVPN_status()
    get_lnd_hybrid_status()
    get_cln_hybrid_status()
    get_wireguard_status()

    return jsonify({})

# to update plebvpn
@socketio.on('update_scripts')
def update_scripts():
    # reset update_available
    global update_available
    update_available = False
    # update pleb-vpn
    cmd_str = [os.path.join(EXEC_DIR, "pleb-vpn.install.sh") + " update 1"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    print(result.stdout, result.stderr)

##############################
### pleb-vpn config routes ###
##############################

# pleb-vpn main page
@views.route('/pleb-VPN', methods=['GET', 'POST'])
@login_required
def pleb_VPN():
    # upload plebvpn.conf file
    if request.method == 'POST':
        # check if the post request has the file part
        if 'plebvpn_conf' not in request.files:
            flash('No file part', category='error')
            return redirect(request.url)
        file = request.files['plebvpn_conf']
        # If the user does not select a file, the browser submits an empty file without a filename.
        if file.filename == '':
            flash('No selected file', category='error')
            return redirect(request.url)
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            # make directory if it doesn't exist
            if not os.path.exists(PLEBVPN_CONF_UPLOAD_FOLDER):
                os.mkdir(PLEBVPN_CONF_UPLOAD_FOLDER)
            file.save(os.path.join(PLEBVPN_CONF_UPLOAD_FOLDER, filename))
            get_plebVPN_status()
            flash('Upload successful!', category='success')

    return render_template("pleb-vpn.html", user=current_user, setting=get_conf(), plebVPN_status=plebVPN_status)

# turn pleb-vpn on or off
@views.route('/set_plebVPN', methods=['POST'])
def set_plebVPN():
    # turns pleb-vpn connection to vps on or off
    setting = get_conf()
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if setting['plebvpn'] == 'on':
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "vpn-install.sh") + " off 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('Pleb-VPN disconnected.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "vpn-install.sh") + " on 1 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('Pleb-VPN connected!', category='success')
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

# delete pleb-vpn conf file
@views.route('/delete_plebvpn_conf', methods=['POST'])
def delete_plebvpn_conf():
    # delete plebvpn.conf from pleb-vpn/openvpn
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if os.path.exists(PLEBVPN_CONF_UPLOAD_FOLDER + '/plebvpn.conf'):
                os.remove(PLEBVPN_CONF_UPLOAD_FOLDER + '/plebvpn.conf')
                get_plebVPN_status()
                flash('plebvpn.conf file deleted', category='success')
    
    return jsonify({})

# checks if plebvpn.conf is a valid .conf file
def allowed_file(filename):
    return '.' in filename and \
        filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

#########################
### Hybrid routes ###
#########################

# hybrid home page
@views.route('/hybrid', methods=['GET', 'POST'])
@login_required
def hybrid():
    # determine whether LND, CLN, or both node implementations are available for hybrid mode
    lnd = False
    cln = False
    lndpath = os.path.join('/etc/systemd/system', 'lnd.service')
    clnpath = os.path.join('/etc/systemd/system', 'lightningd.service')
    if os.path.exists(lndpath):
        lnd = True
    if os.path.exists(clnpath):
        cln = True
    # get new LND or CLN port
    if request.method == 'POST':
        if "lnPort" in request.form:
            lnPort = request.form.get('lnPort')
            if not lnPort.isdigit():
                flash('Error! LND Hybrid Port must be four numbers (example: 9739)', category='error')
            elif len(lnPort) != 4:
                flash('Error! LND Hybrid Port must be four numbers (example: 9739)', category='error')
            else:
                conf_file.set_option('lnport', lnPort)
                conf_file.write()
                flash('Received new LND Port: ' + lnPort, category='success') 
        if "clnPort" in request.form:
            clnPort = request.form.get('clnPort')
            if not clnPort.isdigit():
                flash('Error! CLN Hybrid Port must be four numbers (example: 9739)', category='error')
            elif len(clnPort) != 4:
                flash('Error! CLN Hybrid Port must be four numbers (example: 9739)', category='error')
            else:
                conf_file.set_option('clnport', clnPort)
                conf_file.write()
                flash('Received new LND Port: ' + clnPort, category='success') 

    return render_template('hybrid.html', user=current_user, setting=get_conf, lnd=lnd, cln=cln())

# turn lnd hybrid mode on or off
@views.route('/set_lndHybrid', methods=['POST'])
def set_lndHybrid():
    # turns lnd hybrid mode on or off
    setting = get_conf()
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if setting['lndhybrid'] == 'on':
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "lnd-hybrid.sh") + " off"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('LND Hybrid mode disabled.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "lnd-hybrid.sh") + " on 1 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('LND Hybrid mode enabled!', category='success')
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

# turn cln hybrid mode on or off
@views.route('/set_clnHybrid', methods=['POST'])
def set_clnHybrid():
    # turns cln hybrid mode on or off
    setting = get_conf()
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if setting['clnhybrid'] == 'on':
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "cln-hybrid.sh") + " off"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('Core Lightning Hybrid mode disabled.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "cln-hybrid.sh") + " on 1 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('Core Lightning Hybrid mode enabled!', category='success')
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

#######################
### payments routes ###
#######################

# payments home page
@views.route('/payments', methods=['GET', 'POST'])
@login_required
def payments():
    # determine whether LND, CLN, or both node implementations are available for sending payments
    lnd = False
    cln = False
    lndpath = os.path.join('/etc/systemd/system', 'lnd.service')
    clnpath = os.path.join('/etc/systemd/system', 'lightningd.service')
    if os.path.exists(lndpath):
        lnd = True
    if os.path.exists(clnpath):
        cln = True
    if request.method == 'POST':
        frequency = request.form['frequency']
        pubkey = request.form['pubkey']
        amount = request.form['amount']
        denomination = request.form['denomination']
        node = request.form['node']
        if 'old_payment_id' in request.form:
            old_payment_id = request.form['old_payment_id']
        else:
            old_payment_id = None
        if request.form['message'] is not None:
            message = request.form['message']
        else:
            message = None
        is_valid = valid_payment(frequency, node, pubkey, amount, denomination)
        if is_valid == "0":
            if old_payment_id is not None:
                cmd_str = ["sudo bash " + os.path.join(EXEC_DIR, "payments/managepayments.sh") + " deletepayment " + old_payment_id + " 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
            if message is not None:
                payment_string = frequency + " " + node + " " + pubkey + " " + amount + " " + denomination + " \"" + message + "\""
            else:
                payment_string = frequency + " " + node + " " + pubkey + " " + amount + " " + denomination
            cmd_str = ["sudo bash " + os.path.join(EXEC_DIR, "payments/managepayments.sh") + " newpayment " + payment_string]
            print(cmd_str) # for debug purposes only
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
            # for debug purposes
            print(result.stdout, result.stderr)
            if result.returncode == 0:
                flash('Payment saved and scheduled!', category='success')
            else:
                flash('An unknown error occured!', category='error')
        else:
            flash(is_valid, category='error')

    return render_template('payments.html', user=current_user, current_payments=get_payments(), lnd=lnd, cln=cln)

# delete payment
@views.route('/delete_payment', methods=['POST'])
def delete_payment():
    payment_id = json.loads(request.data)
    payment_id = payment_id['payment_id']
    cmd_str = ["sudo bash " + os.path.join(EXEC_DIR, "payments/managepayments.sh") + " deletepayment " + payment_id + " 1"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('Payment deleted!', category='success')
    else:
        flash('An unknown error occured!', category='error')

    return jsonify({})

# delete all payments
@views.route('/delete_all_payments', methods=['POST'])
def delete_all_payments():
    cmd_str = ["sudo bash " + os.path.join(EXEC_DIR, "payments/managepayments.sh") + " deleteall 1"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('All payments deleted!', category='success')
    else:
        flash('An unknown error occured!', category='error')
    
    return jsonify({})

# send payment now
@views.route('/send_payment', methods=['POST'])
def send_payment():
    payment_id = json.loads(request.data)
    payment_id = payment_id['payment_id']
    cmd_str = ["sudo -u bitcoin " + os.path.join(EXEC_DIR, "payments/keysends/_") + payment_id + "_keysend.sh"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('Payment sent!', category='success')
    else:
        flash('An unknown error occured!', category='error')
    parts = payment_id.split("_")
    cmd_str = ["sudo systemctl enable payments-" + parts[1] + "-" + parts[2] + ".timer"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)
    cmd_str = ["sudo systemctl start payments-" + parts[1] + "-" + parts[2] + ".timer"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)

    return jsonify({})

# checks to see if new payment is valid
def valid_payment(frequency, node, pubkey, amount, denomination):
    is_valid = str(0)
    if frequency != "daily":
        if frequency != "weekly":
            if frequency != "monthly":
                if frequency != "yearly":
                    is_valid = "Error: the frequency must be either 'daily', 'weekly', 'monthly', or 'yearly'"
    if node != "lnd" and node != "cln":
        is_valid = "Error: node type must be either 'lnd' or 'cln'"
    pattern = r'^[a-zA-Z0-9]{66}$'
    match = re.match(pattern, pubkey)
    if not match:
        is_valid = "Error: you did not submit a valid pubkey"
    if denomination == "USD":
        pattern = r'^\d+\.\d{2}$'
        match = re.match(pattern, amount)
        if not match:
            is_valid = "Error: you did not input a valid amount. Amount must be in the form of x.xx for USD and must only contain digits and a decimal"
    elif denomination == "sats":
        if not amount.isdigit():
            is_valid = "Error: you did not input a valid amount. Amount for sats must only contain digits"
    else:
        is_valid = "Error: you did not input a valid denomination. Denomination must either be 'sats' or 'USD'"

    return is_valid

########################
### wireguard routes ###
########################

# wireguard main page
@views.route('/wireguard', methods=['GET', 'POST'])
@login_required
def wireguard():
    # get new Wireguard port
    if request.method == 'POST':
        if "wgPort" in request.form:
            wgPort = request.form.get('wgPort')
            if not wgPort.isdigit():
                flash('Error! Wireguard Port must be four numbers (example: 9739)', category='error')
            elif len(wgPort) != 4:
                flash('Error! Wireguard Port must be four numbers (example: 9739)', category='error')
            else:
                conf_file.set_option('wgport', wgPort)
                conf_file.write()
                flash('Received new Wireguard Port: ' + wgPort, category='success') 

    return render_template('wireguard.html', user=current_user, setting=get_conf())

# get wireguard client qr code
@views.route('/wireguard/clientqrcode', methods=['POST'])
def generate_qr_code():
    filename = json.loads(request.data)
    filename = filename['filename']
    # Read the contents of the text file
    path = os.path.join(HOME_DIR, 'wireguard/clients', filename)
    with open(path, 'r') as f:
        file_contents = f.read()

    # Generate the QR code
    qr = qrcode.QRCode(version=1, box_size=5, border=3)
    qr.add_data(file_contents)
    qr.make(fit=True)

    # Convert the QR code to a PNG image
    img = qr.make_image(fill_color='black', back_color='white')
    img_io = io.BytesIO()
    img.save(img_io, 'PNG')
    img_io.seek(0)

    # Encode the image as base64
    img_base64 = base64.b64encode(img_io.getvalue()).decode()

    # Return the image as a JSON response
    return jsonify(image=img_base64)

# download wireguard client file
@views.route('/wireguard/download_client')
def download_file():
    # Get the filename from the URL query string
    filename = request.args.get('filename')
    path = os.path.join(HOME_DIR, 'wireguard/clients', filename)
    # Check if the file exists
    if not os.path.exists(path):
        return "File not found", 404
    return send_file(path, as_attachment=True)

# set wireguard on or off
@views.route('/set_wireguard', methods=['POST'])
def set_wireguard():
    # turns wireguard on or off
    setting = get_conf()
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if setting['wireguard'] == 'on':
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "wg-install.sh") + " off"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_wireguard_status()
                if result.returncode == 0:
                    flash('Wireguard disabled.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                # check if no wireguard IP in pleb-vpn.conf, and if not, generate one
                if not is_valid_ip(setting['wgip']):
                    while True:
                        new_wgIP = '10.' + str(random.randint(0, 255)) + '.' + str(random.randint(0, 255)) + '.' + str(random.randint(0, 252))
                        print(new_wgIP) # for debug purposes only
                        if is_valid_ip(new_wgIP):
                            break
                    conf_file.set_option('wgip', new_wgIP)
                    conf_file.write()
                    cmd_str = ["sudo " + os.path.join(EXEC_DIR, "wg-install.sh") + " on 0 1 1"]
                else:
                    if os.path.isfile(os.path.join(HOME_DIR, 'wireguard/wg0.conf')):
                        cmd_str = ["sudo " + os.path.join(EXEC_DIR, "wg-install.sh") + " on 1 0 1"]
                    else:
                        cmd_str = ["sudo " + os.path.join(EXEC_DIR, "wg-install.sh") + " on 0 1 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_wireguard_status()
                if result.returncode == 0:
                    flash('Wireguard private LAN enabled!', category='success')
                elif result.returncode == 10:
                    flash('Error: unable to find conf files. Create new conf files and re-enable wireguard.', category='error') 
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

# delete wireguard conf files
@views.route('/delete_wireguard_conf', methods=['POST'])
@login_required
def delete_wireguard_conf():
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if os.path.exists(os.path.join(HOME_DIR, 'wireguard')):
                shutil.rmtree(os.path.join(HOME_DIR, 'wireguard'))
            conf_file.set_option('wgip', '')
            conf_file.set_option('wglan', '')
            conf_file.set_option('wgport', '')
            conf_file.write()

    return jsonify({})

# checks if wireguard ip selected is a valid ip
def is_valid_ip(ip_str):
    setting = get_conf()
    # check that the IP does not match our local IP
    if setting['lan'] in ip_str:
        return False
    # Split the IP address into four parts
    parts = ip_str.split('.')
    if len(parts) != 4:
        return False
    # Convert each part to an integer
    try:
        parts = [int(part) for part in parts]
    except ValueError:
        return False
    # Check that each part is in the valid range
    if parts[0] != 10:
        return False
    if not (0 <= parts[1] <= 255):
        return False
    if not (0 <= parts[2] <= 255):
        return False
    if not (0 <= parts[3] <= 252):
        return False
    # If all checks pass, return True
    return True

##################################
### tor split-tunneling routes ###
##################################

# tor split-tunneling home page
@views.route('/torsplittunnel', methods=['GET'])
@login_required
def torsplittunnel():
    # tor split-tunneling
    if torsplittunnel_status == {}:
        get_torsplittunnel_status()

    return render_template('tor-split-tunnel.html', user=current_user, setting=get_conf(), torsplittunnel_status=torsplittunnel_status, torsplittunnel_test_status=torsplittunnel_test_status)

# set tor split-tunneling on or off
@views.route('/set_torsplittunnel', methods=['POST'])
def set_torsplittunnel():
    # turns tor split-tunneling on or off
    setting = get_conf()
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if setting['torsplittunnel'] == 'on':
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " off 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_torsplittunnel_status()
                if result.returncode == 0:
                    flash('tor split-tunneling disabled.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                cmd_str = ["sudo " + os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " on 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_torsplittunnel_status()
                if result.returncode == 0:
                    flash('tor split-tunneling enabled!', category='success')
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

##########################
### letsencrypt routes ###
##########################

# letsencrypt home page
@views.route('/letsencrypt', methods=['GET'])
@login_required
def letsencrypt():
    message = request.args.get('message')
    category = request.args.get('category')

    if message is not None:
        print('flashing message: ', message) # for debug purposes only
        flash(message, category=category)

    return render_template('letsencrypt.html', user=current_user, setting=get_conf())

# turn letsencrypt on and get certs
@socketio.on('set_letsencrypt_on')
def set_letsencrypt_on(formData):
    setting=get_conf()
    # get ssl certs
    btcpaydomain = formData['btcpaydomain']
    lnbitsdomain = formData['lnbitsdomain']
    btcpay = formData['letsencryptbtcpay']
    lnbits = formData['letsencryptlnbits']
    letsencryptbtcpay = "off"
    letsencryptlnbits = "off"
    if btcpay:
        ipaddress1 = check_domain(btcpaydomain)
        if ipaddress1 != setting['vpnip']:
            message = 'BTCPayServer domain is not a valid domain or does not point to your node public IP.'
            category = 'error'
            socketio.emit("letsencrypt_set_on", {'message': message, 'category': category})
            return
        else:
            letsencryptbtcpay = "on"
            letsencryptdomain1 = btcpaydomain
            letsencryptdomain2 = ""
    if lnbits:
        ipaddress2 = check_domain(lnbitsdomain)
        if ipaddress2 != setting['vpnip']:
            message = 'LNBits domain is not a valid domain or does not point to your node public IP.'
            category = 'error'
            socketio.emit("letsencrypt_set_on", {'message': message, 'category': category})
            return
        else:
            letsencryptlnbits = "on"
            if btcpay:
                letsencryptdomain2 = lnbitsdomain
            else:
                letsencryptdomain1 = lnbitsdomain
                letsencryptdomain2 = ""
    cmd_str = os.path.join(EXEC_DIR, "letsencrypt.install.sh") + " on 0 0 1 " + letsencryptbtcpay + " " + letsencryptlnbits + " " + letsencryptdomain1 + " " + letsencryptdomain2
    exit_code = get_certs(cmd_str, False, False)
    if exit_code == 0:
        message = 'LetsEncrypt certificates installed!'
        category = 'success'
    elif exit_code == int(42069):
        message = 'Script exited with unknown status.'
        category = 'info'
    else:
        message = 'LetsEncrypt certificate install unsuccessful. Please check your domain name(s) and try again, ensuring you enter the CNAME record correctly.'
        category = 'error'
    socketio.emit('letsencrypt_set_on', {'message': message, 'category': category})

# turn letsencrypt off and delete certs
@socketio.on('set_letsencrypt_off')
def set_letsencrypt_off():
    cmd_str = [os.path.join(EXEC_DIR, "letsencrypt.install.sh") + " off"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)
    if result.returncode == 0:
        message = 'LetsEncrypt certificates deleted, origninal config restored.'
        category = 'success'
    else:
        message = 'An unknown error occured!'
        category = 'error'
    socketio.emit('letsencrypt_set_off', {'message': message, 'category': category})

# execute letsencrypt script with pexpect interactively
def get_certs(cmd_str, suppress_output = True, suppress_input = True):
    debug_file = open(os.path.abspath('./debug_output.txt'), "w") # for debug purposes only
    debug_inout = open(os.path.abspath('./debug_inout.txt'), "w") # for debug purposes only
    global enter_input
    enter_yes = False
    yes_count = 0
    enter_count = 0
    end_script = False
    capture_output = False
    capture_output_trigger = str("Output from acme-dns-auth.py")
    capture_output_trigger_off = str("Waiting for verification...")
    enter_yes_trigger = str("(Y)es/(N)o:")
    child = pexpect.spawn('/bin/bash')
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output = child.before.decode('utf-8')
        cmd_line = output.strip()
        print('cmd_line: ', cmd_line, file=debug_file) # for debug purposes only
        if output: # for debug purposes only
            print('first output: ', output.strip(), file=debug_file) # for debug purposes only
    except pexpect.TIMEOUT:
        pass
    child.sendline(cmd_str)
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output1 = child.before.decode('utf-8')
        output1 = output1.replace(cmd_line, '')
        if output1 != output: 
            output = output1
            print(output.strip(), file=debug_file) # for debug purposes only
    except pexpect.TIMEOUT:
        pass
    while True:
        try:
            child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
            output1 = child.before.decode('utf-8')
            if cmd_line in output1:
                end_script = True
            if output1 != output:
                output = output1
                print(output.strip(), file=debug_file) # for debug purposes only
                if capture_output_trigger in output:
                    print("capture_output_trigger received: " + output, file=debug_inout) # for debug purposes only
                    capture_output = True
                    print("capture_output set to: " + str(capture_output), file=debug_inout) # for debug purposes only
                if enter_yes_trigger in output:
                    if yes_count < 1:
                        enter_yes = True
                    print("enter_yes_trigger received: " + output + "\n enter_yes=" + str(enter_yes), file=debug_inout) # for debug purposes only
                if suppress_output == False: 
                    if capture_output:
                        socketio.emit('CNAMEoutput', output.strip().replace(cmd_line, ''))
                        if capture_output_trigger_off in output:
                            print("capture_output_off received: " + output, file=debug_inout) # for debug purposes only
                            capture_output = False
                            print("capture_output set to: " + str(capture_output), file=debug_inout) # for debug purposes only
                            socketio.emit('CNAMEoutput', str('First update the CNAME record(s) of your domain(s) as shown above. After the CNAME records are updated, press "Enter" below.'))
        except pexpect.TIMEOUT:
            pass
        if not suppress_input:
            if enter_yes:
                # print("Sending to terminal: Y", file=debug_file) # for debut only
                if yes_count < 1:
                    child.sendline("Y")
                    yes_count += 1
                    print('sent Y to child', file=debug_inout)
                    enter_yes = False
                    print("enter_yes set to: " + str(enter_yes), file=debug_inout) # for debug purposes only
            if enter_input:
                # print("Sending ENTER to terminal", file=debug_file) # for debug purposes only
                if enter_count < 1:
                    child.sendline('')
                    enter_count += 1
                print('sent enter from enter_input to child', file=debug_inout)
                enter_input = False
                print("enter_input set to: " + str(enter_input), file=debug_inout) # for debug purposes only
        if child.eof() or end_script:
            break
    time.sleep(0.1)
    child.sendline('echo "exit_code=$?"')
    # Wait for the command to complete and capture the output
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
    except pexpect.TIMEOUT:
        pass
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
    except pexpect.TIMEOUT:
        pass
    output = child.before.decode('utf-8')
    # Parse the output to extract the $? value
    print('Exit code command result: ', output.strip().replace(cmd_line, ''), file=debug_file) # for debug purposes only
    if output.strip().replace(cmd_line, '').startswith("exit_code="):
        exit_code = int(output.strip().replace(cmd_line, '').split("=")[-1])
    else:
        exit_code = int(42069)
    print('Exit code = ', exit_code, file=debug_file) # for debug purposes only
    child.close()
    debug_file.close() # for debug purposes only
    
    return exit_code

# checks if the domain(s) for letsencrypt are valid and point to vps ip
def check_domain(domain):
    # Split the domain into its components
    parts = domain.split('.')
    # Ensure the domain has at least two parts (e.g., 'example.com')
    if len(parts) < 2:
        return False
    # Check if each part of the domain is valid
    for part in parts:
        if not part.isalnum():
            return False
    try:
        # Retrieve the IP address associated with the domain
        ip_address = socket.gethostbyname(domain)
        return ip_address
    except socket.gaierror:
        return False

############################################
### status, config, and helper functions ###
############################################

# get pleb-vpn config file values
def get_conf():
    setting = {}
    with open(os.path.join(HOME_DIR, 'pleb-vpn.conf')) as conf:
        for line in conf:
            if "=" in line:
                name, value = line.split("=")
                setting[name] = str(value).rstrip().strip('\'\'')
    return setting

# get status of openvpn connection
def get_plebVPN_status():
    # get status of pleb-vpn connection to vps
    global plebVPN_status
    global update_available
    plebVPN_status = {}
    cmd_str = [os.path.join(EXEC_DIR, "vpn-install.sh") + " status 1"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.join(EXEC_DIR, 'pleb-vpn_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                plebVPN_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'pleb-vpn_status.tmp'))
    setting=get_conf()
    repo_date = check_repository_updated('mynode') # mynode branch included for testing purposes
    if setting['versiondate'] != repo_date:
        update_available = True


# get status of lnd hybrid mode
def get_lnd_hybrid_status():
    # get status of lnd hybrid mode
    global lnd_hybrid_status
    lnd_hybrid_status = {}
    cmd_str = ["sudo " + os.path.join(EXEC_DIR, "lnd-hybrid.sh") + " status 1"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.join(EXEC_DIR, 'lnd_hybrid_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                lnd_hybrid_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'lnd_hybrid_status.tmp'))

# get status of CLN hybrid mode
def get_cln_hybrid_status():
    # get status of CLN hybrid mode
    global cln_hybrid_status
    cln_hybrid_status = {}
    cmd_str = ["sudo " + os.path.join(EXEC_DIR, "cln-hybrid.sh") + " status 1"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.join(EXEC_DIR, 'cln_hybrid_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                cln_hybrid_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'cln_hybrid_status.tmp'))

# get status of wireguard
def get_wireguard_status():
    # get status of wireguard service
    global wireguard_status
    wireguard_status = {}
    cmd_str = ["sudo " + os.path.join(EXEC_DIR, "wg-install.sh") + " status 1"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.join(EXEC_DIR, 'wireguard_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                wireguard_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'wireguard_status.tmp'))

# get current payments scheduled
def get_payments():
    # get current payments
    current_payments = {}
    cmd_str = ["sudo bash " + os.path.join(EXEC_DIR, "payments/managepayments.sh") + " status 1"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.join(EXEC_DIR, 'payments/current_payments.tmp')) as payments:
        for line in payments:
            line_parts = re.findall(r'"[^"]*"|\S+', line.strip())
            try:
                category = line_parts[0]
                id = line_parts[1]
                node = line_parts[2]
                pubkey = line_parts[3]
                amount = line_parts[4]
                denomination = line_parts[5]
                if denomination == "usd":
                    denomination = "USD"
                if len(line_parts) >= 7:
                    message = line_parts[6].strip('"')
                else:
                    message = ""
                if category not in current_payments:
                    current_payments[category] = []
                current_payments[category].append((id, node, pubkey, amount, denomination, message))
            except IndexError:
                print("Error: Not enough elements in line_parts for line: ", line)

    os.remove(os.path.join(EXEC_DIR, 'payments/current_payments.tmp'))
    return current_payments

# get status of tor split-tunneling
def get_torsplittunnel_status():
    # get status of tor split-tunnel service
    global torsplittunnel_status
    torsplittunnel_status = {}
    cmd_str = ["sudo " + os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " status 1 1 1"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                torsplittunnel_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp'))

# run test of tor split-tunneling service
@views.route('/get_torsplittunnel_test_status', methods=['POST'])
def get_torsplittunnel_test_status():
    # test status of tor split-tunnel service
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            global torsplittunnel_test_status
            torsplittunnel_test_status = {}
            cmd_str = ["sudo " + os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " status 1 0 1"]
            subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
            with open(os.path.join(EXEC_DIR, 'split-tunnel_test_status.tmp')) as status:
                for line in status:
                    if "=" in line:
                        name, value = line.split("=")
                        torsplittunnel_test_status[name] = str(value).rstrip().strip('\'\'')
            os.remove(os.path.join(EXEC_DIR, 'split-tunnel_test_status.tmp'))

    return jsonify({})

# get enter input for commands run using pexpect (needed for letsencrypt script)
@socketio.on('enter_input')
def set_enter_input():
    debug_file = open(os.path.abspath('./debug_enter.txt'), "w") # for debug purposes only
    global enter_input
    enter_input = True
    print("set_enter_input: !ENTER!", str(enter_input), file=debug_file) # debug purposes only
    debug_file.close() # for debug purposes only

# check date of last commit to https://github.com/allyourbankarebelongtous/pleb-vpn/
def check_repository_updated(branch=""):
    url = f"https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/commits/{branch}"
    print("url =", url)
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        print("json response")
        print(data)

        if data:  # Check if data is not empty
            last_commit_date = data["commit"]["committer"]["date"]
            dt = datetime.strptime(last_commit_date, "%Y-%m-%dT%H:%M:%SZ")
            formatted_date = dt.strftime("%Y-%m-%d %H:%M:%S %z")
            print("formatted_date=", formatted_date)
            return formatted_date
        else:
            print("no data")
            return None
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        return None
