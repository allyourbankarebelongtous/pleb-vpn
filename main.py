from webui import create_app
from flask_socketio import SocketIO
import subprocess

app = create_app()
socketio = SocketIO(app)

if __name__ == '__main__':
    socketio.run(host = "0.0.0.0", port = 2420, debug=True)

else:
    gunicorn_app = create_app()

@socketio.on('message')
def handle_message(message):
    cmd_str = ["/mnt/hdd/mynode/pleb-vpn/test.enter.sh"]
    process = subprocess.Popen(
        cmd_str,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.PIPE
    )
    for line in iter(process.stdout.readline, ''):
        socketio.emit('output', line.decode('utf-8'))