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
def home():
    global plebVPN_status
    if plebVPN_status == {}:
        get_plebVPN_status()
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

@views.route('/lnd-hybrid', methods=['GET', 'POST'])
@login_required
def lnd_Hybrid():

    return render_template('lnd-hybrid.html', user=current_user)

""" @socketio.on('start_process')
def start_process(data):
    # create a pseudo-terminal
    global user_input
    global enter_input
    master, slave = pty.openpty()

    # start the command as a new process with the slave PTY as its controlling terminal
    cmd_str = ["./" + data]
    pid = os.spawnvp(os.P_NOWAIT, cmd_str[0], cmd_str)

    # loop to read output and send user input to the process
    while True:
        # check if there's any output from the process
        if select.select([master], [], [], 0)[0]:
            output = os.read(master, 1024).decode()
            print(output.strip())
            socketio.emit('output', output.strip())

        # check if there's any user input from the client
        if user_input is not None:
            print("Sending to process: ", user_input)
            os.write(master, user_input.encode() + b'\n')
            user_input = None

        # check if there's any enter input from the client
        if enter_input is True:
            print("Sending ENTER to process:")
            os.write(master, b'\r')
            enter_input = False

        # check if the process has exited
        if os.waitpid(pid, os.WNOHANG)[0] != 0:
            break

        time.sleep(0.1) """

""" @socketio.on('start_process')
def start_process(data):
    global user_input
    global enter_input
    cmd_str = ["./" + data]
    result = subprocess.Popen(cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE, shell=True)
    while True:
        while result.stdout in select.select([result.stdout], [], [], 0)[0]:
            output = result.stdout.readline().decode()
            if output:
                print(output.strip())
                socketio.emit('output', output.strip())
        if user_input is not None:
            print("Sending to stdin: ", user_input)
            result.stdin.write(user_input.encode() + b'\n')
            result.stdin.flush()
            user_input = None
        if enter_input is True:
            print("Sending ENTER to stdin:")
            enter_key = keyboard.press_and_release('enter')
            result.stdin.write(enter_key.encode())
            result.stdin.flush()
            enter_input = False  
        if result.poll() is not None:
            result.stdin.close()
            break
        time.sleep(0.1) """

""" @socketio.on('start_process')
def start_process(data):
    global user_input
    global enter_input
    cmd_str = ["./" + data]
    master, slave = pty.openpty()
    result = os.fork()
    if result == 0:  # Child process
        os.close(master)
        os.dup2(slave, 0)  # Redirect stdin to the slave end of the pseudo-terminal
        os.dup2(slave, 1)  # Redirect stdout to the slave end of the pseudo-terminal
        os.dup2(slave, 2)  # Redirect stderr to the slave end of the pseudo-terminal
        os.close(slave)
        os.execvp(cmd_str[0], cmd_str)
    else:  # Parent process
        #os.close(slave)
        while True:
            r, _, _ = select.select([master], [], [], 0)
            if master in r:
                output = os.read(master, 1024).decode()
                if output:
                    print(output.strip())
                    socketio.emit('output', output.strip())
            if user_input is not None:
                print("Sending to master end of pseudo-terminal: ", user_input)
                os.write(master, user_input.encode() + b'\n')
                user_input = None
            if enter_input is True:
                print("Sending ENTER to slave end of pseudo-terminal:")
                os.write(slave, b'\r')
                enter_input = False
            if os.waitpid(result, os.WNOHANG)[0] != 0:
                os.close(master)
                os.close(slave)
                break
            time.sleep(0.1)
 """
""" @socketio.on('start_process')
def start_process(data):
    global user_input
    global enter_input
    cmd_str = ["./" + data]
    master, slave = pty.openpty()
    result = os.fork()
    if result == 0:  # Child process
        os.close(master)
        os.dup2(slave, 0)  # Redirect stdin to the slave end of the pseudo-terminal
        os.dup2(slave, 1)  # Redirect stdout to the slave end of the pseudo-terminal
        os.dup2(slave, 2)  # Redirect stderr to the slave end of the pseudo-terminal
        os.close(slave)
        os.execvp(cmd_str[0], cmd_str)
    else:  # Parent process
        os.close(slave)
        while True:
            r, _, _ = select.select([master], [], [], 0)
            if master in r:
                output = os.read(master, 1024).decode()
                if output:
                    print(output.strip())
                    socketio.emit('output', output.strip())
            if user_input is not None:
                print("Sending to master end of pseudo-terminal: ", user_input)
                os.write(master, user_input.encode() + b'\n')
                user_input = None
            if enter_input is True:
                print("Sending ENTER to slave end of pseudo-terminal:")
                try:
                    os.write(slave, b'\r')
                except OSError:
                    pass
                enter_input = False
            if os.waitpid(result, os.WNOHANG)[0] != 0:
                os.close(master)
                try:
                    os.close(slave)
                except OSError:
                    pass
                break
            time.sleep(0.1) """

@socketio.on('start_process')
def start_process(data):
    global user_input
    global enter_input
    cmd_str = ["./" + data]
    child = pexpect.spawn('/bin/bash')
    child.sendline('bash', cmd_str)
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output = child.before.decode('utf-8')
        if output:
            print(output.strip())
            socketio.emit('output', output.strip()) 
    except pexpect.TIMEOUT:
        pass
    while True:
        try:
            child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
            output1 = child.before.decode('utf-8')
            if output1 != output: 
                output = output1
                print(output.strip())
                socketio.emit('output', output.strip()) 
        except pexpect.TIMEOUT:
            pass
        if user_input is not None:
            print("Sending to terminal: ", user_input)
            child.sendline(user_input)
            user_input = None
        if enter_input is True:
            print("Sending ENTER to terminal")
            child.sendline('')
            enter_input = False
        if child.eof():
            break
    # Wait for the command to complete and capture the output
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
    except pexpect.TIMEOUT:
        pass
    output = child.before.decode('utf-8')
    # Send a command to the shell to print the exit code
    child.sendline('echo "exit_code=$?"')
    # Wait for the command to complete and capture the output
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
    except pexpect.TIMEOUT:
        pass
    output += child.before.decode('utf-8')
    # Parse the output to extract the $? value
    lines = output.strip().split("\n")
    last_line = lines[0] if lines else ""
    print(last_line)
    if last_line.startswith("exit_code="):
        exit_code = int(last_line.split("=")[-1])
    else:
        exit_code = int(42069)
    print(exit_code)
    child.close()
    if exit_code == 0:
        print('flashing message: Script exited successfully!, category=success')
        flash('Script exited successfully!', category='success')
    elif exit_code == 42069:
        print('flashing message: Script exited., category=info')
        flash('Script exited.', category='info')
    else:
        print('flashing message: Script exited with an error., category=error')
        flash('Script exited with an error.', category='error')

@socketio.on('update_scripts')
def update_scripts():
    global update_available
    global user_input
    global enter_input
    # update pleb-vpn (not for production)
    cmd_str = ["/mnt/hdd/mynode/pleb-vpn/pleb-vpn.install.sh", "update"]
    child = pexpect.spawn('bash', cmd_str)
    try:
        child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
        output = child.before.decode('utf-8')
        if output:
            print(output.strip())
            socketio.emit('output', output.strip()) 
    except pexpect.TIMEOUT:
        pass
    while True:
        try:
            child.expect(['\r\n', pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
            output1 = child.before.decode('utf-8')
            if output1 != output: 
                output = output1
                print(output.strip())
                socketio.emit('output', output.strip()) 
        except pexpect.TIMEOUT:
            pass
        if user_input is not None:
            print("Sending to terminal: ", user_input) 
            child.sendline(user_input)
            user_input = None
        if enter_input is True:
            print("Sending ENTER to terminal")
            child.sendline('')
            enter_input = False
        if child.eof():
            break
    # Wait for the command to complete and capture the output
    child.expect([pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
    output = child.before.decode('utf-8')
    # Send a command to the shell to print the exit code
    child.sendline('echo "exit_code=$?"')
    # Wait for the command to complete and capture the output
    child.expect([pexpect.EOF, pexpect.TIMEOUT], timeout=0.1)
    output += child.before.decode('utf-8')
    # Parse the output to extract the $? value
    lines = output.strip().split("\n")
    last_line = lines[-1] if lines else ""
    print(last_line)
    if last_line.startswith("exit_code="):
        exit_code = int(last_line.split("=")[-1])
    else:
        exit_code = 42069
    print(exit_code)
    if exit_code == 0:
        flash('Pleb-VPN update successful! Click restart to restart Pleb-VPN', category='success')
        update_available = True
    elif exit_code == int(42069):
        flash('Script exited.', category='info')
        update_available = True
    else:
        flash('Pleb-VPN update unsuccessful. Check your internet connection and try again.', category='error')

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

@socketio.on('user_input')
def set_user_input(input):
    global user_input
    user_input = input
    print("set_user_input: ", user_input)

@socketio.on('enter_input')
def set_enter_input():
    global enter_input
    enter_input = True
    print("set_enter_input: !ENTER!", enter_input)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
