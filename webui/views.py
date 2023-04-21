from flask import Blueprint, render_template, request, flash, jsonify, redirect, url_for, session
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
from socket_io import socketio
from .models import User
from . import db
import json, os, subprocess, keyboard, select, time, pty, pexpect

views = Blueprint('views', __name__)

ALLOWED_EXTENSIONS = {'conf'}
PLEBVPN_CONF_UPLOAD_FOLDER = '/mnt/hdd/mynode/pleb-vpn/openvpn'
conf_file_location = '/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf'
plebVPN_status = {}
user_input = None
enter_input = False
update_available = False

@views.route('/', methods=['GET', 'POST'])
@login_required
def home(message = None, category = None):
    global plebVPN_status
    if plebVPN_status == {}:
        get_plebVPN_status()
    if message is not None:
        print('flashing message: ', message) # for debug purposes only
        flash(message, category=category)
    return render_template("home.html", 
                           user=current_user, 
                           setting=get_conf(), 
                           plebVPN_status=plebVPN_status, 
                           update_available=update_available)

@views.route('/refresh_plebVPN_data', methods=['POST'])
@login_required
def refresh_plebVPN_data():
    # refresh pleb-vpn status of connection to vps
    get_plebVPN_status()

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
            if setting['plebVPN'] == 'on':
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

@views.route('/lnd-hybrid', methods=['GET'])
@login_required
def lnd_Hybrid(message = None, category = None):

    if message is not None:
        print('flashing message: ', message) # for debug purposes only
        flash(message, category=category)

    return render_template('lnd-hybrid.html', user=current_user)

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
    return redirect(url_for('views.home', message=message, category=category))

@socketio.on('update_scripts')
def update_scripts():
    global update_available
    # update pleb-vpn (not for production)
    cmd_str = ["/mnt/hdd/mynode/pleb-vpn/pleb-vpn.install.sh update"]
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

    return redirect(url_for('views.lnd_Hybrid', message=message, category=category))

def set_conf(name, value):
    setting = get_conf()
    if not setting[name]:
        cmd_str = ["sed", "-i", "2i" + name + "=", conf_file_location]
        subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    cmd_str = ["sed", "-i", "s:^" + name + "=.*:" + name + "=" + value + ":g", conf_file_location]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

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
    cmd_str = ["/mnt/hdd/mynode/pleb-vpn/vpn-install.sh reboot"]
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
