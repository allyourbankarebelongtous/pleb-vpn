from flask import Blueprint, render_template, request, flash, jsonify, redirect, url_for, session
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
from socket_io import socketio
from .models import User
from . import db
import json, os, subprocess, keyboard, asyncio

views = Blueprint('views', __name__)

ALLOWED_EXTENSIONS = {'conf'}
PLEBVPN_CONF_UPLOAD_FOLDER = '/mnt/hdd/mynode/pleb-vpn/openvpn'
conf_file_location = '/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf'
plebVPN_status = {}
user_input = None
enter_input = False

@views.route('/', methods=['GET', 'POST'])
@login_required
def home():
    if plebVPN_status == {}:
        get_plebVPN_status()
    return render_template("home.html", user=current_user, setting=get_conf(), plebVPN_status=plebVPN_status)

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

@views.route('/lnd-hybrid', methods=['GET', 'POST'])
@login_required
def lnd_Hybrid():

    return render_template('lnd-hybrid.html', user=current_user)

""" @socketio.on('start_process')
def start_process(data):
    cmd_str = ["./" + data]
    result = subprocess.Popen(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, shell=True)

    while True:
        output = result.stdout.readline().decode()
        if output:
            print(output.strip())
            socketio.emit('output', output.strip())
        user_input = get_user_input()
        if user_input is not None:
            print("Sending to stdin: ", user_input)
            result.stdin.write(user_input.encode() + b'\n')
            result.stdin.flush()
            user_input = None
        enter_input = get_enter_input()
        if enter_input is True:
            print("Sending ENTER to stdin:")
            result.stdin.write('\n'.encode())
            result.stdin.flush()
            enter_input = False  
        if result.poll() is not None:
            result.stdin.close()
            break """

@socketio.on('start_process')
def start_process(data):
    cmd_str = ["./" + data]
    result = subprocess.Popen(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, shell=True)

    def handle_output():
        while True:
            output = result.stdout.readline().decode()
            if output:
                print(output.strip())
                socketio.emit('output', output.strip())
            user_input = get_user_input()
            if user_input is not None:
                print("Sending to stdin: ", user_input)
                result.stdin.write(user_input.encode() + b'\n')
                result.stdin.flush()
                user_input = None
            enter_input = get_enter_input()
            if enter_input is True:
                print("Sending ENTER to stdin:")
                result.stdin.write('\n'.encode())
                result.stdin.flush()
                enter_input = False  
            if result.poll() is not None:
                result.stdin.close()
                break

    asyncio.run_coroutine_threadsafe(handle_output(), asyncio.get_event_loop())

@socketio.on('user_input')
def set_user_input(input):
    global user_input
    user_input = input
    print("set_user_input: ", user_input)

@socketio.on('enter_input')
def set_enter_input(input):
    global enter_input
    print("received enter_input: !ENTER!")
    enter_input = True
    print("set_enter_input: !ENTER!", enter_input)

def get_user_input():
    global user_input
    print("returned user_input: ", user_input)
    return user_input

def get_enter_input():
    global enter_input
    print("returned enter_input: !ENTER! ", enter_input)
    return enter_input

@views.route('/update_scripts', methods=['POST'])
def update_scripts():
    # test random scripts (not for production)
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if os.path.exists(os.path.abspath('./pleb-vpn.install.sh')):
                cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/pleb-vpn.install.sh update"]
                result = subprocess.Popen(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, shell=True)
                # Loop through the output of the Bash script in real-time
                while True:
                    output = result.stdout.readline().decode()
                    if output:
                        print(output.strip())
                    if result.poll() is not None:
                        break
                    # Prompt the user for input while the script is running (will resume after hitting enter)
                    if "Press ENTER to continue" in output.strip():
                        pause_key(message = "Press ENTER to continue", key = 'enter')
                        # Check if the subprocess has finished before writing to its stdin stream  
                        if result.poll() is None:
                            result.stdin.write(b'\n')
                            result.stdin.flush()
                            # Always close stdin stream
                            result.stdin.close()
                # Print the final output of the Bash script
                output, error = result.communicate()
                if output:
                    print(output.decode())
                    message = output.decode()
                    flash(message, category='success')
                if error:
                    print(error.decode())
                    message = error.decode()
                    flash(message, category='error')
    
    return jsonify({})

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
    cmd_str = ["sudo /mnt/hdd/mynode/pleb-vpn/vpn-install.sh status"]
    subprocess.run(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    with open(os.path.abspath('./pleb-vpn_status.tmp')) as status:
        for line in status:
            if "=" in line:
                name, value = line.split("=")
                plebVPN_status[name] = str(value).rstrip().strip('\'\'')
    os.remove(os.path.abspath('./pleb-vpn_status.tmp'))

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def pause_key(message, key):
    flash(message, category='warning')
    paused = True
    while paused:
        if keyboard.read_key() == key:
            paused = False
