from flask_socketio import SocketIO
import eventlet

eventlet.monkey_patch()

socketio = SocketIO(async_mode='eventlet')