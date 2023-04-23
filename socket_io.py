from flask_socketio import SocketIO
from gevent import monkey

monkey.patch_all()

socketio = SocketIO(async_mode='gevent', websocket=True)