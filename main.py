from webui import create_app
from socket_io import socketio

app = create_app()
socketio.init_app(app)

if __name__ == '__main__':
    socketio.run(app, host = "0.0.0.0", port = 2420, debug=True)

else:
    gunicorn_app = socketio.run(app)