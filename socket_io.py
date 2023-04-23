from flask_socketio import SocketIO

socketio = SocketIO(async_mode='gevent', websocket=True)