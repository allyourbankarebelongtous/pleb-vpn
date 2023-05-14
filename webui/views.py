from flask import Blueprint, render_template, request, flash, jsonify, redirect, url_for, session, send_file
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
from socket_io import socketio
from datetime import datetime, timedelta
from plebvpn_common import config
# from PIL import Image
from .models import User
from . import db
import json, os, subprocess, time, pexpect, random, qrcode, io, base64, shutil, re, datetime

views = Blueprint('views', __name__)

ALLOWED_EXTENSIONS = {'conf'}
PLEBVPN_CONF_UPLOAD_FOLDER = '/mnt/hdd/mynode/pleb-vpn/openvpn'
conf_file_location = '/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf'
conf_file = config.PlebConfig(conf_file_location)
plebVPN_status = {}
lnd_hybrid_status = {}
wireguard_status = {}
torsplittunnel_status = {}
torsplittunnel_test_status = {}
user_input = None
enter_input = False
update_available = False

@views.route('/', methods=['GET', 'POST'])
@login_required
def home():
    if plebVPN_status == {}:
        get_plebVPN_status()
    if lnd_hybrid_status == {}:
        get_lnd_hybrid_status()
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
                           wireguard_status=wireguard_status,
                           update_available=update_available)

@views.route('/refresh_plebVPN_data', methods=['POST'])
@login_required
def refresh_plebVPN_data():
    # refresh pleb-vpn status of connection to vps
    get_plebVPN_status()
    get_lnd_hybrid_status()
    get_wireguard_status()

    return jsonify({})

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
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/vpn-install.sh off"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('Pleb-VPN disconnected.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/vpn-install.sh on"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('Pleb-VPN connected!', category='success')
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

@views.route('/delete_plebvpn_conf', methods=['POST'])
def delete_plebvpn_conf():
    # delete plebvpn.conf from pleb-vpn/openvpn
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if os.path.exists(os.path.abspath('./openvpn/plebvpn.conf')):
                os.remove(os.path.abspath('./openvpn/plebvpn.conf'))
                get_plebVPN_status()
                flash('plebvpn.conf file deleted', category='success')
    
    return jsonify({})

@views.route('/lnd-hybrid', methods=['GET', 'POST'])
@login_required
def lnd_hybrid():
    # get new LND port
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

    return render_template('lnd-hybrid.html', user=current_user, setting=get_conf())

@views.route('/set_lndHybrid', methods=['POST'])
def set_lndHybrid():
    # turns pleb-vpn connection to vps on or off
    setting = get_conf()
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if setting['lndhybrid'] == 'on':
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/lnd-hybrid.sh off"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('LND Hybrid mode disabled.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/lnd-hybrid.sh on 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_plebVPN_status()
                if result.returncode == 0:
                    flash('LND Hybrid mode enabled!', category='success')
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

@views.route('/payments', methods=['GET', 'POST'])
@login_required
def payments():
    if request.method == 'POST':
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
        is_valid = valid_payment(frequency, pubkey, amount, denomination)
        if is_valid == "0":
            if old_payment_id is not None:
                cmd_str = ["sudo bash /mnt/hdd/mynode/pleb-vpn/payments/managepayments.sh deletepayment " + old_payment_id]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
            if message is not None:
                payment_string = frequency + " " + pubkey + " " + amount + " " + denomination + " \"" + message + "\""
            else:
                payment_string = frequency + " " + pubkey + " " + amount + " " + denomination
            cmd_str = ["sudo bash /mnt/hdd/mynode/pleb-vpn/payments/managepayments.sh newpayment " + payment_string]
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

    return render_template('payments.html', user=current_user, current_payments=get_payments())

@views.route('/delete_payment', methods=['POST'])
def delete_payment():
    payment_id = json.loads(request.data)
    payment_id = payment_id['payment_id']
    cmd_str = ["sudo bash /mnt/hdd/mynode/pleb-vpn/payments/managepayments.sh deletepayment " + payment_id]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('Payment deleted!', category='success')
    else:
        flash('An unknown error occured!', category='error')

    return jsonify({})

@views.route('/delete_all_payments', methods=['POST'])
def delete_all_payments():
    cmd_str = ["sudo bash /mnt/hdd/mynode/pleb-vpn/payments/managepayments.sh deleteall 1"]
    result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    # for debug purposes
    print(result.stdout, result.stderr)
    if result.returncode == 0:
        flash('All payments deleted!', category='success')
    else:
        flash('An unknown error occured!', category='error')
    
    return jsonify({})

@views.route('/send_payment', methods=['POST'])
def send_payment():
    payment_id = json.loads(request.data)
    payment_id = payment_id['payment_id']
    cmd_str = ["sudo -u bitcoin /mnt/hdd/mynode/pleb-vpn/payments/keysends/_" + payment_id + "_keysend.sh"]
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

@views.route('/wireguard/clientqrcode', methods=['POST'])
def generate_qr_code():
    filename = json.loads(request.data)
    filename = filename['filename']
    # Read the contents of the text file
    path = os.path.join('/mnt/hdd/mynode/pleb-vpn/wireguard/clients', filename)
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

@views.route('/wireguard/download_client')
def download_file():
    # Get the filename from the URL query string
    filename = request.args.get('filename')
    path = os.path.join('/mnt/hdd/mynode/pleb-vpn/wireguard/clients', filename)
    # Check if the file exists
    if not os.path.exists(path):
        return "File not found", 404
    return send_file(path, as_attachment=True)

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
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/wg-install.sh off"]
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
                    cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/wg-install.sh on 1"]
                else:
                    if os.path.isfile('/mnt/hdd/mynode/pleb-vpn/wireguard/wg0.conf'):
                        cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/wg-install.sh on"]
                    else:
                        cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/wg-install.sh on 1"]
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

@views.route('/delete_wireguard_conf', methods=['POST'])
@login_required
def delete_wireguard_conf():
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if os.path.exists('/mnt/hdd/mynode/pleb-vpn/wireguard'):
                shutil.rmtree('/mnt/hdd/mynode/pleb-vpn/wireguard')
            conf_file.set_option('wgip', '')
            conf_file.set_option('wglan', '')
            conf_file.set_option('wgport', '')
            conf_file.write()

    return jsonify({})

@views.route('/torsplittunnel', methods=['GET'])
@login_required
def torsplittunnel():
    # tor split-tunneling
    if torsplittunnel_status == {}:
        get_torsplittunnel_status()

    return render_template('tor-split-tunnel.html', user=current_user, setting=get_conf(), torsplittunnel_status=torsplittunnel_status, torsplittunnel_test_status=torsplittunnel_test_status)

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
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/tor.split-tunnel.sh off 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_torsplittunnel_status()
                if result.returncode == 0:
                    flash('tor split-tunneling disabled.', category='success')
                else:
                    flash('An unknown error occured!', category='error')
            else:
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/tor.split-tunnel.sh on 1"]
                result = subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
                # for debug purposes
                print(result.stdout, result.stderr)
                get_torsplittunnel_status()
                if result.returncode == 0:
                    flash('tor split-tunneling enabled!', category='success')
                else:
                    flash('An unknown error occured!', category='error')

    return jsonify({})

@views.route('/test-scripts', methods=['GET'])
@login_required
def test_scripts():
    message = request.args.get('message')
    category = request.args.get('category')

    if message is not None:
        print('flashing message: ', message) # for debug purposes only
        flash(message, category=category)

    return render_template('test-scripts.html', user=current_user)

@socketio.on('start_process')
def start_process(data):

    cmd_str = str(data)
    exit_code = run_cmd(cmd_str, False, False)
    print('Back on start_process, the exit code received from run_cmd(cmd_str) is: ', exit_code)
    if exit_code == 0:
        message = 'Script exited successfully!'
        category = 'success'
    elif exit_code == 42069:
        message = 'Script exited with unknown status.'
        category = 'info'
    else:
        message = 'Script exited with an error.'
        category = 'error'

    print('before returning, message = ', message, 'category = ', category) # for debug purposes only
    socketio.emit('process_complete', {'message': message, 'category': category})

@socketio.on('update_scripts')
def update_scripts():
    global update_available
    # update pleb-vpn (not for production)
    cmd_str = "/mnt/hdd/mynode/pleb-vpn/pleb-vpn.install.sh update"
    exit_code = run_cmd(cmd_str, False, False)
    if exit_code == 0:
        message = 'Pleb-VPN update successful! Click restart to restart Pleb-VPN webui.'
        category = 'success'
        update_available = True
    elif exit_code == int(42069):
        message = 'Script exited with unknown status. Click restart to restart Pleb-VPN webui.'
        category = 'info'
        update_available = True
    else:
        message = 'Pleb-VPN update unsuccessful. Check your internet connection and try again.'
        category = 'error'

    print('before returning, message = ', message, 'category = ', category) # for debug purposes only
    socketio.emit('update_complete', {'message': message, 'category': category})

def get_conf():
    setting = {}
    with open(os.path.abspath('./pleb-vpn.conf')) as conf:
        for line in conf:
            if "=" in line:
                name, value = line.split("=")
                setting[name] = str(value).rstrip().strip('\'\'')
    return setting

def get_plebVPN_status():
    # get status of pleb-vpn connection to vps
    global plebVPN_status
    plebVPN_status = {}
    cmd_str = ["/mnt/hdd/mynode/pleb-vpn/vpn-install.sh status"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.abspath('./pleb-vpn_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                plebVPN_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.abspath('./pleb-vpn_status.tmp'))

def get_lnd_hybrid_status():
    # get status of lnd hybrid mode
    global lnd_hybrid_status
    lnd_hybrid_status = {}
    cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/lnd-hybrid.sh status"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.abspath('./lnd_hybrid_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                lnd_hybrid_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.abspath('./lnd_hybrid_status.tmp'))

def get_wireguard_status():
    # get status of wireguard service
    global wireguard_status
    wireguard_status = {}
    cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/wg-install.sh status"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.abspath('./wireguard_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                wireguard_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.abspath('./wireguard_status.tmp'))

def get_payments():
    # get current payments
    current_payments = {}
    # today = datetime.now()
    # yesterday = datetime.now() - timedelta(days=1)
    # sunday = today - datetime.timedelta(days=today.weekday())
    # saturday = sunday - timedelta(days=1)
    # first_of_month = datetime(today.year, today.month, 1)
    # last_of_month = first_of_month - timedelta(days=1)
    # first_of_year = datetime(today.year, 1, 1)
    # last_of_year = first_of_year - timedelta(days=1)
    # today = datetime(today.year, today.month, today.day, 1, 0, 0)
    # yesterday = datetime(yesterday.year, yesterday.month, yesterday.day, 23, 0, 0)
    # sunday = datetime(sunday.year, sunday.month, sunday.day, 1, 0, 0)
    # saturday = datetime(saturday.year, saturday.month, saturday.day, 23, 0, 0)
    # first_of_month = datetime(first_of_month.year, first_of_month.month, first_of_month.day, 1, 0, 0)
    # last_of_month = datetime(last_of_month.year, last_of_month.month, last_of_month.day, 23, 0, 0)
    # first_of_year = datetime(first_of_year.year, first_of_year.month, first_of_year.day, 1, 0, 0)
    # last_of_year = datetime(last_of_year.year, last_of_year.month, last_of_year.day, 23, 0, 0)
    # today = today.strftime("%Y-%m-%d %H:%M:%S")
    # yesterday = yesterday.strftime("%Y-%m-%d %H:%M:%S")
    # sunday = sunday.strftime("%Y-%m-%d %H:%M:%S")
    # saturday = saturday.strftime("%Y-%m-%d %H:%M:%S")
    # first_of_month = first_of_month.strftime("%Y-%m-%d %H:%M:%S")
    # last_of_month = last_of_month.strftime("%Y-%m-%d %H:%M:%S")
    # first_of_year = first_of_year.strftime("%Y-%m-%d %H:%M:%S")
    # last_of_year = last_of_year.strftime("%Y-%m-%d %H:%M:%S")
    cmd_str = ["sudo bash /mnt/hdd/mynode/pleb-vpn/payments/managepayments.sh status"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.abspath('./payments/current_payments.tmp')) as payments:
        for line in payments:
            line_parts = re.findall(r'"[^"]*"|\S+', line.strip())
            try:
                category = line_parts[0]
                id = line_parts[1]
                pubkey = line_parts[2]
                amount = line_parts[3]
                denomination = line_parts[4]
                if denomination == "usd":
                    denomination = "USD"
                if len(line_parts) >= 6:
                    message = line_parts[5].strip('"')
                else:
                    message = ""
                if category not in current_payments:
                    current_payments[category] = []
                # if category == 'daily':
                #     start_date = "start=$(date -d '" + yesterday + "' +%s); "
                #     end_date = "end=$(date -d '" + today + "' +%s); "
                # elif category == 'weekly':
                #     start_date = "start=$(date -d '" + saturday + "' +%s); "
                #     end_date = "end=$(date -d '" + sunday + "' +%s); "
                # elif category == 'monthly':
                #     start_date = "start=$(date -d '" + last_of_month + "' +%s); "
                #     end_date = "end=$(date -d '" + first_of_month + "' +%s); "
                # elif category == 'yearly':
                #     start_date = "start=$(date -d '" + last_of_year + "' +%s); "
                #     end_date = "end=$(date -d '" + first_of_year + "' +%s); "
                # else:
                #     start_date = "error"
                #     end_date = "error"
                
                current_payments[category].append((id, pubkey, amount, denomination, message))
            except IndexError:
                print("Error: Not enough elements in line_parts for line: ", line)

    os.remove(os.path.abspath('./payments/current_payments.tmp'))
    return current_payments

def get_torsplittunnel_status():
    # get status of tor split-tunnel service
    global torsplittunnel_status
    torsplittunnel_status = {}
    cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/tor.split-tunnel.sh status"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.abspath('./split-tunnel_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                torsplittunnel_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.abspath('./split-tunnel_status.tmp'))

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
            cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/tor.split-tunnel.sh status 1"]
            subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
            with open(os.path.abspath('./split-tunnel_test_status.tmp')) as status:
                for line in status:
                    if "=" in line:
                        name, value = line.split("=")
                        torsplittunnel_test_status[name] = str(value).rstrip().strip('\'\'')
            os.remove(os.path.abspath('./split-tunnel_test_status.tmp'))

    return jsonify({})

@socketio.on('user_input')
def set_user_input(input):
    global user_input
    user_input = input
    print("set_user_input: ", user_input) # debug purposes only

@socketio.on('enter_input')
def set_enter_input():
    global enter_input
    enter_input = True
    print("set_enter_input: !ENTER!", enter_input) # debug purposes only

@socketio.on('start_reboot')
def start_reboot():
    global update_available
    print("starting reboot") # debug purposes only
    cmd_str = "/mnt/hdd/mynode/pleb-vpn/vpn-install.sh reboot"
    update_available = False
    run_cmd(cmd_str)

def run_cmd(cmd_str, suppress_output = True, suppress_input = True):
    global user_input
    global enter_input
    end_script = False
    child = pexpect.spawn('/bin/bash')
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output = child.before.decode('utf-8')
        cmd_line = output.strip()
        print('cmd_line: ', cmd_line) # for debug purposes only
        socketio.emit('output', 'cmd_line: ' + cmd_line + '\n') # for debug purposes only
        if output: # for debug purposes only
            print('first output: ', output.strip()) # for debug purposes only
            socketio.emit('output', 'first output: ' + output.strip() + '\n')  # for debug purposes only
    except pexpect.TIMEOUT:
        pass
    child.sendline(cmd_str)
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output1 = child.before.decode('utf-8')
        output1 = output1.replace(cmd_line, '')
        if output1 != output: 
            output = output1
            print(output.strip()) # for debug purposes only
            socketio.emit('output', output.strip() + '\n')  # for debug purposes only
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
                if suppress_output == False:
                    print(output.strip().replace(cmd_line, '')) # for debug purposes only
                    socketio.emit('output', output.strip().replace(cmd_line, '') + '\n') 
        except pexpect.TIMEOUT:
            pass
        if not suppress_input:
            if user_input is not None:
                print("Sending to terminal: ", user_input) # for debug purposes only
                child.sendline(user_input)
                user_input = None
            if enter_input is True:
                print("Sending ENTER to terminal") # for debug purposes only
                child.sendline('')
                enter_input = False
        if child.eof() or end_script:
            break
    # # Wait for the command to complete and capture the output
    # try:
    #     child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
    # except pexpect.TIMEOUT:
    #     pass
    # output = child.before.decode('utf-8')
    # Send a command to the shell to print the exit code
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
    print('Exit code command result: ', output.strip().replace(cmd_line, '')) # for debug purposes only
    socketio.emit('Exit code command result: ', output.strip().replace(cmd_line, '') + '\n')  # for debug purposes only
    if output.strip().replace(cmd_line, '').startswith("exit_code="):
        exit_code = int(output.strip().replace(cmd_line, '').split("=")[-1])
    else:
        exit_code = int(42069)
    print('Exit code = ', exit_code) # for debug purposes only
    socketio.emit('Exit code = ', str(exit_code) + '\n')  # for debug purposes only
    child.close()
    
    return exit_code

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

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

def valid_payment(frequency, pubkey, amount, denomination):
    is_valid = str(0)
    if frequency != "daily":
        if frequency != "weekly":
            if frequency != "monthly":
                if frequency != "yearly":
                    is_valid = "Error: the frequency must be either 'daily', 'weekly', 'monthly', or 'yearly'"
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