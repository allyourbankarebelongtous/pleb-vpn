from webui import create_app
from socketio import socketio
import subprocess

app = create_app()

if __name__ == '__main__':
    socketio.run(app, host = "0.0.0.0", port = 2420, debug=True)

else:
    gunicorn_app = create_app()