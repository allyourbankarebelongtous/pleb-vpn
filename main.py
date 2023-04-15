from webui import create_app
from flask_socketio import SocketIO

app = create_app()
socketio = SocketIO(app)

if __name__ == '__main__':
    socketio.run(host = "0.0.0.0", port = 2420, debug=True)

else:
    gunicorn_app = create_app()