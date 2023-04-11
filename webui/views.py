from flask import Blueprint, Flask, render_template, request, flash, jsonify, request, redirect, url_for
from flask_login import login_required, current_user
from werkzeug.utils import secure_filename
from .models import User
from . import db
import json, os, subprocess

views = Blueprint('views', __name__)

ALLOWED_EXTENSIONS = {'conf'}
UPLOAD_FOLDER = '/mnt/hdd/mynode/pleb-vpn/'
conf_file_location = '/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf'
plebVPN_status = {}

@views.route('/', methods=['GET', 'POST'])
@login_required
def home():
    return render_template("home.html", user=current_user, setting=get_conf(), plebVPN_status=plebVPN_status)

@views.route('/refresh_plebVPN_data', methods=['POST'])
@login_required
def refresh_plebVPN_data():
    global plebVPN_status
    # generate new .tmp file
    # for testing purposes, rename pleb-vpn_status1.tmp
    os.rename(os.path.abspath('./pleb-vpn_status1.tmp'), os.path.abspath('./pleb-vpn_status.tmp'))
    plebVPN_status = get_plebVPN_status()
    # delete pleb-vpn_status.tmp file
    os.rename(os.path.abspath('./pleb-vpn_status.tmp'), os.path.abspath('./pleb-vpn_status1.tmp'))

    return jsonify({})

@views.route('/pleb-VPN', methods=['GET', 'POST'])
@login_required
def pleb_VPN():
    if request.method == 'POST':
        # check if the post request has the file part
        if 'plebvpn_conf' not in request.files:
            flash('No file part', category='error')
            return redirect(request.url)
        file = request.files['plebvpn_conf']
        # If the user does not select a file, the browser submits an
        # empty file without a filename.
        if file.filename == '':
            flash('No selected file', category='error')
            return redirect(request.url)
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            file.save(os.path.join(UPLOAD_FOLDER, filename))
            flash('Upload successful!', category='success')

    return render_template("pleb-vpn.html", user=current_user, setting=get_conf(), plebVPN_status=plebVPN_status)

@views.route('/set_plebVPN', methods=['POST'])
def set_plebVPN():
    setting = get_conf()
    user = json.loads(request.data)
    userId = user['userId']
    user = User.query.get(userId)
    if user:
        if user.id == current_user.id:
            if setting['plebVPN'] == 'on':
                set_conf('plebVPN', 'off')
                flash('Pleb-VPN disconnected', category='success')
            else:
                set_conf('plebVPN', 'on')
                flash('Pleb-VPN connected!', category='success')
    
    return jsonify({})

def set_conf(name, value):
    setting = get_conf()
    if not setting[name]:
        cmd_str = ["sed", "-i", "2i" + name + "=", conf_file_location]
        subprocess.run(cmd_str, shell=True)
    cmd_str = [sed_exe, "-i", "s:^" + name + "=.*:" + name + "=" + value + ":g", conf_file_location]
    print(cmd_str)
    subprocess.run(cmd_str, shell=True)

def get_conf():
    setting = {}
    with open(os.path.abspath('./pleb-vpn.conf')) as conf:
        for line in conf:
            if "=" in line:
                name, value = line.split("=")
                setting[name] = str(value).rstrip().strip('\'\'')
    return setting

def get_plebVPN_status():
    plebVPN_status = {}
    if os.path.exists(os.path.abspath('./pleb-vpn_status.tmp')):
        with open(os.path.abspath('./pleb-vpn_status.tmp')) as status:
            for line in status:
                if "=" in line:
                    name, value = line.split("=")
                    plebVPN_status[name] = str(value).rstrip().strip('\'\'')
    return plebVPN_status

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS