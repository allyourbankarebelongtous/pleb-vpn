from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from werkzeug.security import generate_password_hash
import secrets, os, shutil, subprocess

db = SQLAlchemy()
DB_NAME = "pleb-vpn.db"
if os.path.exists('/mnt/hdd/mynode/'):
    HOME_DIR = str('/mnt/hdd/mynode/pleb-vpn')
    EXEC_DIR = str('/opt/mynode/pleb-vpn')
if os.path.exists('/mnt/hdd/raspiblitz.conf') or os.path.exists('/mnt/hdd/app-data/raspiblitz.conf'):
    HOME_DIR = str('/mnt/hdd/app-data/pleb-vpn')
    EXEC_DIR = str('/home/admin/pleb-vpn')

def create_app():
    app = Flask(__name__)

    if os.path.exists(os.path.abspath('./.secretKey.conf')):
        with open(os.path.abspath('./.secretKey.conf'), 'r') as secretKey:
            secret_key = secretKey.read()
    else:
        secret_key = secrets.token_urlsafe(16)
        with open(os.path.abspath('./.secretKey.conf'), 'w') as secretKey:
            secretKey.write(secret_key)

    app.config['SECRET_KEY'] = secret_key
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + DB_NAME
    db.init_app(app)

    from .views import views
    from .auth import auth

    app.register_blueprint(views, url_prefix='/')
    app.register_blueprint(auth, url_prefix='/')

    from .models import User

    with app.app_context():
        db.create_all()

    with app.app_context():
        user = User.query.filter_by(user_name='admin').first()
        if not user:
            if os.path.exists('/mnt/hdd/raspiblitz.conf'): # for raspiblitz, use passwordB
                cmd_str = "cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-"
                new_password = subprocess.check_output(cmd_str, shell=True)
                new_password = new_password.decode().strip()
            else: # otherwise default password is plebvpn
                new_password = 'plebvpn'
            new_user = User(user_name = 'admin', password = generate_password_hash(new_password, method='sha256'))
            db.session.add(new_user)
            db.session.commit()
            # copy database to HOME_DIR
            if os.path.exists(os.path.join(HOME_DIR, 'instance')):
                shutil.rmtree(os.path.join(HOME_DIR, 'instance'))
            shutil.copytree(os.path.join(EXEC_DIR, 'instance'), os.path.join(HOME_DIR, 'instance'))
    
    login_manager = LoginManager()
    login_manager.login_view = 'auth.login'
    login_manager.init_app(app)

    @login_manager.user_loader
    def load_user(id):
        return User.query.get(int(id))
    
    return app
