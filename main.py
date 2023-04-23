from webui import create_app
from socket_io import socketio
from gevent import monkey

app = create_app()
socketio.init_app(app)

if __name__ == '__main__':
    
    monkey.patch_all()
    socketio.run(app, host = "0.0.0.0", port = 2420, debug=True)
