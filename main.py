from flask_cors import CORS
from webui import create_app
from socket_io import socketio
from gevent import monkey
from werkzeug.middleware.proxy_fix import ProxyFix
import logging

logging.basicConfig(level=logging.DEBUG)
app = create_app()

# Enable CORS for the Flask app
CORS(app)

socketio.init_app(app)
# allow nginx proxy to work with socketio
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_host=1)

if __name__ == '__main__':
    monkey.patch_all()
    socketio.run(app, host="0.0.0.0", port=2420, debug=True)