from flask import Blueprint, Flask, render_template, request, flash, jsonify, request, redirect, url_for
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
from .models import User
from . import db
import json, os, subprocess, keyboard

views = Blueprint('views', __name__)

ALLOWED_EXTENSIONS = {'conf'}
PLEBVPN_CONF_UPLOAD_FOLDER = '/mnt/hdd/mynode/pleb-vpn/openvpn'
conf_file_location = '/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf'
plebVPN_status = {}

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

@views.route('/test_scripts', methods=['POST'])
def test_scripts():
    # test random scripts (not for production)
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if os.path.exists(os.path.abspath('./test.enter.sh')):
                cmd_str = ['./test.enter.sh']
                result = subprocess.Popen(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, shell=True)
                # Loop through the output of the Bash script in real-time
                while result.poll() is not None:
                    output = result.stdout.readline().decode()
                    if output:
                        print(output.strip())
                    # Prompt the user for input while the script is running (will resume after hitting enter)
                    user_input = input()
                    # Check if the subprocess has finished before writing to its stdin stream  
                    if output == '' and result.poll() is None:
                        result.stdin.write(user_input.encode() + b'\n')
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
    while True:
        if keyboard.read_key() == key:
            # If you put 'enter' key
            # the program will resume.
            break
