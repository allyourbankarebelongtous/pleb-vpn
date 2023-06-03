from flask import Blueprint, render_template, request, flash, jsonify, redirect, url_for, session, send_file
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
from socket_io import socketio
from flask_socketio import disconnect
from check_update import get_latest_version
from plebvpn_common import config
from .models import User
from . import db
import json, os, subprocess, time, pexpect, random, qrcode, io, base64, shutil, re, socket, requests, re, signal, functools, logging

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
plebVPN_status = {}
lnd_hybrid_status = {}
cln_hybrid_status = {}
wireguard_status = {}
torsplittunnel_status = {}
torsplittunnel_test_status = {}
update_available = False
enter_input = False


# socketio authentication check
def authenticated_only(f):
    @functools.wraps(f)
    def wrapped(*args, **kwargs):
        if not current_user.is_authenticated:
            disconnect()
        else:
            return f(*args, **kwargs)
    return wrapped

########################
### Home Page routes ###
########################

# home page
@views.route('/', methods=['GET'])
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
        logging.debug('flashing message: ', message) # for debug purposes only
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
@socketio.on('refresh_plebVPN_data')
@authenticated_only
def refresh_plebVPN_data():
    # refresh pleb-vpn status of connection to vps
    get_plebVPN_status()
    get_lnd_hybrid_status()
    get_cln_hybrid_status()
    get_wireguard_status()
    get_torsplittunnel_status()
    socketio.emit('plebVPN_data_refreshed')

# to update plebvpn
@socketio.on('update_scripts')
@authenticated_only
def update_scripts():
    # reset update_available
    global update_available
    update_available = False
    # update pleb-vpn
    cmd_str = [os.path.join(EXEC_DIR, "pleb-vpn.install.sh") + " update 1"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
    except subprocess.TimeoutExpired:
        logging.error("Error: pleb-vpn.install.sh update script timed out")
    logging.info(result.stdout, result.stderr)

@socketio.on('uninstall-plebvpn')
@authenticated_only
def uninstall_plebvpn():
    # update pleb-vpn
    cmd_str = [os.path.join(EXEC_DIR, "pleb-vpn.install.sh") + " uninstall"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
    except subprocess.TimeoutExpired:
        logging.error("Error: pleb-vpn.install.sh uninstall script timed out")
    logging.info(result.stdout, result.stderr)

# get pleb-vpn config file values
def get_conf():
    setting = {}
    with open(os.path.join(HOME_DIR, 'pleb-vpn.conf')) as conf:
        for line in conf:
            if "=" in line:
                name, value = line.split("=")
                setting[name] = str(value).rstrip().strip('\'\'')
    return setting

##############################
### pleb-vpn config routes ###
##############################

# pleb-vpn main page
@views.route('/pleb-VPN', methods=['GET', 'POST'])
@login_required
def pleb_VPN():
    # determine whether LND, CLN, or both node implementations are available for hybrid mode
    lnd = False
    cln = False
    lndpath = os.path.join('/etc/systemd/system', 'lnd.service')
    clnpath = os.path.join('/etc/systemd/system', 'lightningd.service')
    if os.path.exists(lndpath):
        lnd = True
    if os.path.exists(clnpath):
        cln = True
    # get message to flash if exists
    message = request.args.get('message')
    category = request.args.get('category')
    if message is not None:
        logging.debug('flashing message: ', message) # for debug purposes only
        flash(message, category=category)
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

    return render_template("pleb-vpn.html", user=current_user, setting=get_conf(), plebVPN_status=plebVPN_status, lnd=lnd, cln=cln)

# turn pleb-vpn on or off
@socketio.on('set_plebVPN')
@authenticated_only
def set_plebVPN():
    # turns pleb-vpn connection to vps on or off
    setting = get_conf()
    if setting['plebvpn'] == 'on':
        cmd_str = [os.path.join(EXEC_DIR, "vpn-install.sh") + " off 1"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: vpn-install.sh off script timed out")
            message = 'Error: vpn-install.sh off script timed out'
            category = 'error'
            socketio.emit('plebVPN_set', {'message': message, 'category': category})
            return
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_plebVPN_status()
        if result.returncode == 0:
            message = 'Pleb-VPN disconnected.'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('plebVPN_set', {'message': message, 'category': category})
    else:
        cmd_str = [os.path.join(EXEC_DIR, "vpn-install.sh") + " on 1 1"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: vpn-install.sh on script timed out")
            message = 'Error: vpn-install.sh on script timed out'
            category = 'error'
            return jsonify({})
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_plebVPN_status()
        if result.returncode == 0:
            message = 'Pleb-VPN connected!'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('plebVPN_set', {'message': message, 'category': category})

# delete pleb-vpn conf file
@views.route('/delete_plebvpn_conf', methods=['POST'])
@login_required
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

# pleb-vpn data refresh
@views.route('/refresh_VPN_data', methods=['POST'])
@login_required
def refresh_VPN_data():
    # refresh pleb-vpn status of connection to vps
    get_plebVPN_status()

    return jsonify({})

# checks if plebvpn.conf is a valid .conf file
def allowed_file(filename):
    return '.' in filename and \
        filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# get status of openvpn connection
def get_plebVPN_status():
    # get status of pleb-vpn connection to vps
    global plebVPN_status
    global update_available
    plebVPN_status = {}
    conf_file = config.PlebConfig(conf_file_location)
    cmd_str = [os.path.join(EXEC_DIR, "vpn-install.sh") + " status 1"]
    try:
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=100)
    except subprocess.TimeoutExpired:
        if os.path.exists(os.path.join(EXEC_DIR, 'pleb-vpn_status.tmp')):
            os.remove(os.path.join(EXEC_DIR, 'pleb-vpn_status.tmp'))
        logging.error('Error: vpn-install.sh status script timed out')
        return
    with open(os.path.join(EXEC_DIR, 'pleb-vpn_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                plebVPN_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'pleb-vpn_status.tmp'))
    setting=get_conf()
    # check for new version of pleb-vpn
    latest_version = str(get_latest_version())
    update_available = False
    if latest_version is not None:
        if setting['version'] != latest_version:
            conf_file.set_option('latestversion', latest_version)
            conf_file.write()
            update_available = True 

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
    if lnd_hybrid_status == {}:
        get_lnd_hybrid_status()
    if cln_hybrid_status == {}:
        get_cln_hybrid_status()
    # get message to flash if exists
    message = request.args.get('message')
    category = request.args.get('category')
    if message is not None:
        logging.debug('flashing message: ', message) # for debug purposes only
        flash(message, category=category)
    # get new LND or CLN port
    if request.method == 'POST':
        conf_file = config.PlebConfig(conf_file_location)
        if "lnPort" in request.form:
            lnPort = request.form.get('lnPort')
            if not lnPort.isdigit():
                flash('Error! LND Hybrid Port must be four or five numbers (example: 9739)', category='error')
            elif len(lnPort) not in [4, 5]:
                flash('Error! LND Hybrid Port must be four or five numbers (example: 9739)', category='error')
            else:
                conf_file.set_option('lnport', lnPort)
                conf_file.write()
                flash('Received new LND Port: ' + lnPort, category='success') 
        if "clnPort" in request.form:
            clnPort = request.form.get('clnPort')
            if not clnPort.isdigit():
                flash('Error! CLN Hybrid Port must be four or five numbers (example: 9739)', category='error')
            elif len(clnPort) not in [4, 5]:
                flash('Error! CLN Hybrid Port must be four or five numbers (example: 9739)', category='error')
            else:
                conf_file.set_option('clnport', clnPort)
                conf_file.write()
                flash('Received new CLN Port: ' + clnPort, category='success') 

    return render_template('hybrid.html', user=current_user, setting=get_conf(), lnd_hybrid_status=lnd_hybrid_status, cln_hybrid_status=cln_hybrid_status, lnd=lnd, cln=cln)

# turn lnd hybrid mode on or off
@socketio.on('set_lndHybrid')
@authenticated_only
def set_lndHybrid():
    # turns lnd hybrid mode on or off
    setting = get_conf()
    if setting['lndhybrid'] == 'on':
        cmd_str = [os.path.join(EXEC_DIR, "lnd-hybrid.sh") + " off"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: lnd-hybrid.sh off script timed out")
            message = 'Error: lnd-hybrid.sh off script timed out'
            category = 'error'
            socketio.emit('lndHybrid_set', {'message': message, 'category': category})
            return
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_plebVPN_status()
        if result.returncode == 0:
            message = 'LND Hybrid mode disabled.'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('lndHybrid_set', {'message': message, 'category': category})
    else:
        cmd_str = [os.path.join(EXEC_DIR, "lnd-hybrid.sh") + " on 1 1"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: lnd-hybrid.sh on script timed out")
            message = 'Error: lnd-hybrid.sh on script timed out'
            category = 'error'
            socketio.emit('lndHybrid_set', {'message': message, 'category': category})
            return
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_plebVPN_status()
        if result.returncode == 0:
            message = 'LND Hybred mode enabled!'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('lndHybrid_set', {'message': message, 'category': category})

# turn cln hybrid mode on or off
@socketio.on('set_clnHybrid')
@authenticated_only
def set_clnHybrid():
    # turns cln hybrid mode on or off
    setting = get_conf()
    if setting['clnhybrid'] == 'on':
        cmd_str = [os.path.join(EXEC_DIR, "cln-hybrid.sh") + " off"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: cln-hybrid.sh off script timed out")
            message = 'Error: cln-hybrid.sh off script timed out'
            category = 'error'
            socketio.emit('clnHybrid_set', {'message': message, 'category': category})
            return
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_plebVPN_status()
        if result.returncode == 0:
            message = 'Core Lightning Hybrid mode disabled.'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('clnHybrid_set', {'message': message, 'category': category})
    else:
        cmd_str = [os.path.join(EXEC_DIR, "cln-hybrid.sh") + " on 1 1"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: cln-hybrid.sh onf script timed out")
            message = 'Error: cln-hybrid.sh on script timed out'
            category = 'error'
            socketio.emit('clnHybrid_set', {'message': message, 'category': category})
            return
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_plebVPN_status()
        if result.returncode == 0:
            message = 'Core Lightning Hybrid mode enabled!'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('clnHybrid_set', {'message': message, 'category': category})

# refresh hybrid data
@views.route('/refresh_hybrid_data', methods=['POST'])
@login_required
def refresh_hybrid_data():
    # refresh lnd and cln hybrid data
    get_lnd_hybrid_status()
    get_cln_hybrid_status()

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
        node = request.form['node']
        frequency = request.form['frequency']
        pubkey = request.form['pubkey']
        amount = request.form['amount']
        denomination = request.form['denomination']
        if 'old_payment_id' in request.form:
            old_payment_id = request.form['old_payment_id']
        else:
            old_payment_id = None
        if request.form['message'] is not None:
            message = request.form['message']
        else:
            message = None
        if denomination == "USD":
            # correct format for USD to always use two decimal places
            amount_parts = amount.split('.')
            if len(amount_parts) == 1:
                amount = amount + ".00"
            elif len(amount_parts[1]) == 1:
                amount = amount + "0"
        # check payment validity
        is_valid = valid_payment(frequency, node, pubkey, amount, denomination)
        if is_valid == "0":
            if old_payment_id is not None:
                cmd_str = [os.path.join(EXEC_DIR, "payments/managepayments.sh") + " deletepayment " + old_payment_id + " 1"]
                try:
                    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=60)
                except subprocess.TimeoutExpired:
                    logging.error("Error: managepayments.sh deletepayment script timed out")
                    flash('Error: managepayments.sh deletepayment script timed out', category='error')
                    return render_template('payments.html', user=current_user, current_payments=get_payments(), lnd=lnd, cln=cln)
            if message is not None:
                # fix message so dollar signs are sent as literall $ and not values
                if '$' in message:
                    message = message.replace('$', r'\$')
                payment_string = frequency + " " + node + " " + pubkey + " " + amount + " " + denomination + " \"" + message + "\""
            else:
                payment_string = frequency + " " + node + " " + pubkey + " " + amount + " " + denomination
            cmd_str = [os.path.join(EXEC_DIR, "payments/managepayments.sh") + " newpayment " + payment_string]
            logging.debug("newpayment command string sent: ", cmd_str) # for debug purposes only
            try:
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=60)
            except subprocess.TimeoutExpired:
                logging.error("Error: managepayments.sh newpayment script timed out")
                flash('Error: managepayments.sh newpayment script timed out', category='error')
                return render_template('payments.html', user=current_user, current_payments=get_payments(), lnd=lnd, cln=cln)
            # for debug purposes
            logging.info(result.stdout, result.stderr)
            if result.returncode == 0:
                flash('Payment saved and scheduled!', category='success')
            else:
                flash('An unknown error occured!', category='error')
        else:
            flash(is_valid, category='error')

    return render_template('payments.html', user=current_user, current_payments=get_payments(), lnd=lnd, cln=cln)

# delete payment
@views.route('/delete_payment', methods=['POST'])
@login_required
def delete_payment():
    payment_id = json.loads(request.data)
    payment_id = payment_id['payment_id']
    cmd_str = [os.path.join(EXEC_DIR, "payments/managepayments.sh") + " deletepayment " + payment_id + " 1"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=60)
    except subprocess.TimeoutExpired:
        logging.error("Error: managepayments.sh deletepayment script timed out") 
        flash('Error: managepayments.sh deletepayment script timed out', category='error')
        return jsonify({})
    # for debug purposes
    logging.info(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('Payment deleted!', category='success')
    else:
        flash('An unknown error occured!', category='error')

    return jsonify({})

# delete all payments
@views.route('/delete_all_payments', methods=['POST'])
@login_required
def delete_all_payments():
    cmd_str = [os.path.join(EXEC_DIR, "payments/managepayments.sh") + " deleteall 1"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=60)
    except subprocess.TimeoutExpired:
        logging.error("Error: managepayments.sh deleteall script timed out")
        flash('Error: managepayments.sh deleteall script timed out', category='error')
        return jsonify({})
    # for debug purposes
    logging.info(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('All payments deleted!', category='success')
    else:
        flash('An unknown error occured!', category='error')
    
    return jsonify({})

# send payment now
@views.route('/send_payment', methods=['POST'])
@login_required
def send_payment():
    payment_id = json.loads(request.data)
    payment_id = payment_id['payment_id']
    cmd_str = ["sudo -u bitcoin " + os.path.join(EXEC_DIR, "payments/keysends/_") + payment_id + "_keysend.sh"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=300)
    except subprocess.TimeoutExpired:
        logging.error("Error: keysend payment script timed out")
        flash('Error: keysend payment script timed out', category='error')
        return jsonify({})
    # for debug purposes
    logging.info(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('Payment sent!', category='success')
    else:
        flash('An unknown error occured!', category='error')
    parts = payment_id.split("_")
    cmd_str = ["systemctl enable payments-" + parts[1] + "-" + parts[2] + ".timer"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=60)
    except subprocess.TimeoutExpired:
        logging.error("Error: enable payment timer command timed out")
        flash('Error: enable payment timer command timed out', category='error')
        return jsonify({})
    # for debug purposes
    logging.info(result.stdout, result.stderr)
    cmd_str = ["systemctl start payments-" + parts[1] + "-" + parts[2] + ".timer"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=60)
    except subprocess.TimeoutExpired:
        logging.error("Error: start payment timer command timed out")
        flash('Error: start payment timer command timed out', category='error')
        return jsonify({})
    # for debug purposes
    logging.info(result.stdout, result.stderr)

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
            is_valid = "Error: you did not input a valid amount. Amount must be a positive integer and contain from zero to two decimal places only."
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
    if wireguard_status == {}:
        get_wireguard_status()
    # get message to flash if exists
    message = request.args.get('message')
    category = request.args.get('category')
    if message is not None:
        logging.debug('flashing message: ', message) # for debug purposes only
        flash(message, category=category)
    # get port
    if request.method == 'POST':
        conf_file = config.PlebConfig(conf_file_location)
        if "wgPort" in request.form:
            wgPort = request.form.get('wgPort')
            if not wgPort.isdigit():
                flash('Error! Wireguard Port must be four or five numbers (example: 9739)', category='error')
            elif len(wgPort) not in [4, 5]:
                flash('Error! Wireguard Port must be four or five numbers (example: 9739)', category='error')
            else:
                conf_file.set_option('wgport', wgPort)
                conf_file.write()
                flash('Received new Wireguard Port: ' + wgPort, category='success') 

    return render_template('wireguard.html', user=current_user, setting=get_conf(), wireguard_status=wireguard_status)

# get wireguard client qr code
@views.route('/wireguard/clientqrcode', methods=['POST'])
@login_required
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
@login_required
def download_file():
    # Get the filename from the URL query string
    filename = request.args.get('filename')
    path = os.path.join(HOME_DIR, 'wireguard/clients', filename)
    # Check if the file exists
    if not os.path.exists(path):
        return "File not found", 404
    return send_file(path, as_attachment=True)

# set wireguard on or off
@socketio.on('set_wireguard')
@authenticated_only
def set_wireguard():
    # turns wireguard on or off
    setting = get_conf()
    if setting['wireguard'] == 'on':
        cmd_str = [os.path.join(EXEC_DIR, "wg-install.sh") + " off"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: wg-install.sh off script timed out")
            message = 'Error: wg-install.sh off script timed out'
            category = 'error'
            socketio.emit('wireguard_set', {'message': message, 'category': category})
            return
        if result.returncode == 0:
            message = 'Wireguard disabled.'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_wireguard_status()
        socketio.emit('wireguard_set', {'message': message, 'category': category})
    else:
        # check if no wireguard IP in pleb-vpn.conf, and if not, generate one
        if not is_valid_ip(setting['wgip']):
            conf_file = config.PlebConfig(conf_file_location)
            while True:
                new_wgIP = '10.' + str(random.randint(0, 255)) + '.' + str(random.randint(0, 255)) + '.' + str(random.randint(0, 252))
                logging.debug(new_wgIP) # for debug purposes only
                if is_valid_ip(new_wgIP):
                    break
            conf_file.set_option('wgip', new_wgIP)
            conf_file.write()
            cmd_str = [os.path.join(EXEC_DIR, "wg-install.sh") + " on 0 1 1"]
        else:
            if os.path.isfile(os.path.join(HOME_DIR, 'wireguard/wg0.conf')):
                cmd_str = [os.path.join(EXEC_DIR, "wg-install.sh") + " on 1 0 1"]
            else:
                cmd_str = [os.path.join(EXEC_DIR, "wg-install.sh") + " on 0 1 1"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: wg-install.sh on script timed out")
            message = 'Error: wg-install.sh on script timed out'
            category = 'error'
            socketio.emit('wireguard_set', {'message': message, 'category': category})
            return
        if result.returncode == 0:
            message = 'Wireguard private LAN enabled!'
            category = 'success'
        elif result.returncode == 10:
            message = 'Error: unable to find conf files. Create new conf files and re-enable wireguard.'
            category = 'error'
        else:
            message = 'An unknown error occured!'
            category = 'error'
                # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_wireguard_status()
        socketio.emit('wireguard_set', {'message': message, 'category': category})

# delete wireguard conf files
@views.route('/delete_wireguard_conf', methods=['POST'])
@login_required
def delete_wireguard_conf():
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            conf_file = config.PlebConfig(conf_file_location)
            if os.path.exists(os.path.join(HOME_DIR, 'wireguard')):
                shutil.rmtree(os.path.join(HOME_DIR, 'wireguard'))
            conf_file.set_option('wgip', '')
            conf_file.set_option('wglan', '')
            conf_file.set_option('wgport', '')
            conf_file.write()

    return jsonify({})

# wireguard data refresh
@views.route('/refresh_wireguard_data', methods=['POST'])
@login_required
def refresh_wireguard_data():
    # refresh pleb-vpn status of connection to vps
    get_wireguard_status()

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
    # get message to flash if exists
    message = request.args.get('message')
    category = request.args.get('category')
    if message is not None:
        flash(message, category=category)

    return render_template('tor-split-tunnel.html', user=current_user, setting=get_conf(), torsplittunnel_status=torsplittunnel_status, torsplittunnel_test_status=torsplittunnel_test_status)

# set tor split-tunneling on or off
@socketio.on('set_torsplittunnel')
@authenticated_only
def set_torsplittunnel():
    # turns tor split-tunneling on or off
    setting = get_conf()
    if setting['torsplittunnel'] == 'on':
        cmd_str = [os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " off 1"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
        except subprocess.TimeoutExpired:
            logging.error("Error: tor.split-tunnel.sh off script timed out")
            message = 'Error: tor.split-tunnel.sh off script timed out'
            category = 'error'
            socketio.emit('torsplittunnel_set', {'message': message, 'category': category})
            return
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_torsplittunnel_status()
        if result.returncode == 0:
            message = 'tor split-tunneling disabled.'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('torsplittunnel_set', {'message': message, 'category': category})
    else:
        cmd_str = [os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " on 1"]
        try:
            result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=900)
        except subprocess.TimeoutExpired:
            logging.error("Error: tor.split-tunnel.sh on script timed out")
            message = 'Error: tor.split-tunnel.sh on script timed out'
            category = 'error'
            socketio.emit('torsplittunnel_set', {'message': message, 'category': category})
            return
        # for debug purposes
        logging.info(result.stdout, result.stderr)
        get_torsplittunnel_status()
        if result.returncode == 0:
            message = 'tor split-tunneling enabled!'
            category = 'success'
        else:
            message = 'An unknown error occured!'
            category = 'error'
        socketio.emit('torsplittunnel_set', {'message': message, 'category': category})

# tor split-tunnel data refresh
@views.route('/refresh_torsplittunnel_data', methods=['POST'])
@login_required
def refresh_torsplittunnel_data():
    # refresh pleb-vpn status of connection to vps
    get_torsplittunnel_status()

    return jsonify({})

# run test of tor split-tunneling service
@socketio.on('test_torsplittunnel')
@authenticated_only
def get_torsplittunnel_test_status():
    # test status of tor split-tunnel service
    global torsplittunnel_test_status
    torsplittunnel_test_status = {}
    cmd_str = [os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " status 1 0 1"]
    try:
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=900)
    except subprocess.TimeoutExpired:
        if os.path.exists(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp')):
            os.remove(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp'))
        logging.error("Error: tor.split-tunnel.sh test script timed out")
        message = 'Tor split-tunnel test timed out'
        category = 'info'
        socketio.emit('torsplittunnel_test_complete', {'message': message, 'category': category})
        return
    with open(os.path.join(EXEC_DIR, 'split-tunnel_test_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                torsplittunnel_test_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'split-tunnel_test_status.tmp'))
    message = 'Tor split-tunnel test complete.'
    category = 'info'
    socketio.emit('torsplittunnel_test_complete', {'message': message, 'category': category})

##########################
### letsencrypt routes ###
##########################

# letsencrypt home page
@views.route('/letsencrypt', methods=['GET'])
@login_required
def letsencrypt():
    setting = get_conf()
    # if user is on raspiblitz, determine if btcpay and/or lnbits are installed, otherwise assume true
    if setting['nodetype'] == 'raspiblitz':
        with open('/mnt/hdd/raspiblitz.conf', 'r') as file:
            config_data = file.read()
        # Extract the values using regular expressions
        lnbits_match = re.search(r'LNBits=(\w+)', config_data)
        btcpay_match = re.search(r'BTCPayServer=(\w+)', config_data)
        # Set variables based on the extracted values
        lnbits_on = lnbits_match.group(1) == 'on' if lnbits_match else False
        btcpay_on = btcpay_match.group(1) == 'on' if btcpay_match else False
    else:
        btcpay_on = True
        lnbits_on = True
    # get message to flash if exists
    message = request.args.get('message')
    category = request.args.get('category')
    if message is not None:
        logging.debug('flashing message: ', message) # for debug purposes only
        flash(message, category=category)

    return render_template('letsencrypt.html', user=current_user, setting=setting, btcpay_on=btcpay_on, lnbits_on=lnbits_on)

# turn letsencrypt on and get certs
@socketio.on('set_letsencrypt_on')
@authenticated_only
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
        if setting['nodetype'] == "mynode":
            # start service to ensure nginx config is correct
            cmd_str = ["systemctl start pleb-vpn-letsencrypt-config.service"]
            try:
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=900)
            except subprocess.TimeoutExpired:
                logging.error("Error: start pleb-vpn-letsencrypt-config.service command timed out")
                message = 'Error: start pleb-vpn-letsencrypt-config.service command timed out'
                category = 'error'
                socketio.emit('letsencrypt_set_on', {'message': message, 'category': category})
                return
            if result.returncode == 0:
                message = 'LetsEncrypt certificates installed!'
                category = 'success'
            else:
                message = 'An unknown error occured!'
                category = 'error'
        else:
            message = 'LetsEncrypt certificates installed!'
            category = 'success'
    elif exit_code == int(42069):
        message = 'Script exited with unknown status.'
        category = 'info'
    elif exit_code == int(420):
        message = 'Script timed out.'
        category = 'error'
    else:
        message = 'LetsEncrypt certificate install unsuccessful. Please check your domain name(s) and try again, ensuring you enter the CNAME record correctly.'
        category = 'error'
    socketio.emit('letsencrypt_set_on', {'message': message, 'category': category})

# turn letsencrypt off and delete certs
@socketio.on('set_letsencrypt_off')
@authenticated_only
def set_letsencrypt_off():
    cmd_str = [os.path.join(EXEC_DIR, "letsencrypt.install.sh") + " off"]
    try:
        result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=600)
    except subprocess.TimeoutExpired:
        logging.error("Error: letsencrypt.install.sh off script timed out")
        message = 'Error: letsencrypt.install.sh off script timed out'
        category = 'error'
        socketio.emit('letsencrypt_set_off', {'message': message, 'category': category})
        return
    # for debug purposes
    logging.info(result.stdout, result.stderr)
    if result.returncode == 0:
        message = 'LetsEncrypt certificates deleted, origninal config restored.'
        category = 'success'
    else:
        message = 'An unknown error occured!'
        category = 'error'
    socketio.emit('letsencrypt_set_off', {'message': message, 'category': category})

# execute letsencrypt script with pexpect interactively
def get_certs(cmd_str, suppress_output = True, suppress_input = True):
    global enter_input
    enter_yes = False
    yes_count = 0
    enter_count = 0
    end_script = False
    capture_output = False
    capture_output_trigger = str("Output from")
    capture_output_trigger_off = str("Waiting for verification...")
    enter_yes_trigger = str("(Y)es/(N)o:")
    child = pexpect.spawn('/bin/bash')
    # Set up the timeout signal handler
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(900)  # Set the alarm for 15 minutes
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output = child.before.decode('utf-8')
        cmd_line = output.strip()
        logging.debug('cmd_line from pexpect: ', cmd_line) # for debug purposes only
        if output: # for debug purposes only
            logging.debug('pexpect first output: ', output.strip()) # for debug purposes only
    except pexpect.TIMEOUT:
        pass
    child.sendline(cmd_str)
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output1 = child.before.decode('utf-8')
        output1 = output1.replace(cmd_line, '')
        if output1 != output: 
            output = output1
            logging.info(output.strip()) # for debug purposes only
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
                logging.info(output.strip()) # for debug purposes only
                if capture_output_trigger in output:
                    logging.debug("capture_output_trigger received: " + output) # for debug purposes only
                    capture_output = True
                    logging.debug("capture_output set to: " + str(capture_output)) # for debug purposes only
                if enter_yes_trigger in output:
                    if yes_count < 1:
                        enter_yes = True
                    logging.debug("enter_yes_trigger received: " + output + "\n enter_yes=" + str(enter_yes)) # for debug purposes only
                if not suppress_output: 
                    if capture_output:
                        socketio.emit('CNAMEoutput', output.strip().replace(cmd_line, ''))
                        if capture_output_trigger_off in output:
                            logging.debug("capture_output_off received: " + output) # for debug purposes only
                            capture_output = False
                            logging.debug("capture_output sent to child: " + str(capture_output)) # for debug purposes only
                            socketio.emit('CNAMEoutput', str('First update the CNAME record(s) of your domain(s) as shown above. After the CNAME records are updated, press "Enter" below.'))
        except pexpect.TIMEOUT:
            pass
        except TimeoutError:
            logging.debug("Letsencrypt pexpect ommand execution timed out") # for debug purposes only
            child.close()
            signal.alarm(0)
            return int(420)
        if not suppress_input:
            if enter_yes:
                if yes_count < 1:
                    child.sendline("Y")
                    yes_count += 1
                    logging.debug('sent Y to child')
                    enter_yes = False
                    logging.debug("enter_yes set to: " + str(enter_yes)) # for debug purposes only
            if enter_input:
                if enter_count < 1:
                    child.sendline('')
                    enter_count += 1
                    socketio.emit('wait_for_confirmation')
                    logging.debug('sent enter from enter_input to child')
                    enter_input = False
                    logging.debug("enter_input set to: " + str(enter_input)) # for debug purposes only
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
    logging.debug('Exit code command result: ', output.strip().replace(cmd_line, '')) # for debug purposes only
    if output.strip().replace(cmd_line, '').startswith("exit_code="):
        exit_code = int(output.strip().replace(cmd_line, '').split("=")[-1])
    else:
        exit_code = int(42069)
    logging.debug('Exit code = ', exit_code) # for debug purposes only
    child.close()
    signal.alarm(0)
    
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

# get enter input for commands run using pexpect (needed for letsencrypt script)
@socketio.on('enter_input')
@authenticated_only
def set_enter_input():
    global enter_input
    enter_input = True
    logging.debug("set_enter_input for pexpect commands:", str(enter_input)) # debug purposes only

# timeout handler for running commands using pexpect
def timeout_handler(signum, frame):
    raise TimeoutError("Command execution timed out")

############################################
### status, config, and helper functions ###
############################################

# get status of lnd hybrid mode
def get_lnd_hybrid_status():
    # get status of lnd hybrid mode
    global lnd_hybrid_status
    lnd_hybrid_status = {}
    cmd_str = [os.path.join(EXEC_DIR, "lnd-hybrid.sh") + " status 1"]
    try:
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=100)
    except subprocess.TimeoutExpired:
        if os.path.exists(os.path.join(EXEC_DIR, 'lnd_hybrid_status.tmp')):
            os.remove(os.path.join(EXEC_DIR, 'lnd_hybrid_status.tmp'))
        logging.error('Error: lnd-hybrid.sh status script timed out')
        return
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
    cmd_str = [os.path.join(EXEC_DIR, "cln-hybrid.sh") + " status 1"]
    try:
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=100)
    except subprocess.TimeoutExpired:
        if os.path.exists(os.path.join(EXEC_DIR, 'cln_hybrid_status.tmp')):
            os.remove(os.path.join(EXEC_DIR, 'cln_hybrid_status.tmp'))
        logging.error('Error: cln_hybrid.sh status script timed out')
        return
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
    cmd_str = [os.path.join(EXEC_DIR, "wg-install.sh") + " status 1"]
    try:
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=100)
    except subprocess.TimeoutExpired:
        if os.path.exists(os.path.join(EXEC_DIR, 'wireguard_status.tmp')):
            os.remove(os.path.join(EXEC_DIR, 'wireguard_status.tmp'))
        logging.error('Error: wg-install.sh status script timed out')
        return
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
    cmd_str = [os.path.join(EXEC_DIR, "payments/managepayments.sh") + " status 1"]
    try:
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=100)
    except subprocess.TimeoutExpired:
        if os.path.exists(os.path.join(EXEC_DIR, 'payments/current_payments.tmp')):
            os.remove(os.path.join(EXEC_DIR, 'payments/current_payments.tmp'))
        logging.error('Error: managepayments.sh status script timed out')
        return
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
                logging.error("Error: When looking up current_payments.tmp, not enough elements in line_parts for line: ", line)

    os.remove(os.path.join(EXEC_DIR, 'payments/current_payments.tmp'))
    return current_payments

# get status of tor split-tunneling
def get_torsplittunnel_status():
    # get status of tor split-tunnel service
    global torsplittunnel_status
    torsplittunnel_status = {}
    cmd_str = [os.path.join(EXEC_DIR, "tor.split-tunnel.sh") + " status 1 1 1"]
    try:
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True, timeout=100)
    except subprocess.TimeoutExpired:
        if os.path.exists(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp')):
            os.remove(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp'))
        logging.error('Error: tor.split-tunnel.sh status script timed out')
        return
    with open(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                torsplittunnel_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.join(EXEC_DIR, 'split-tunnel_status.tmp'))

    return jsonify({})