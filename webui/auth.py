from flask import Blueprint, render_template, request, flash, redirect, url_for
from .models import User
from werkzeug.security import generate_password_hash, check_password_hash
from . import db
from flask_login import login_user, login_required, logout_user, current_user
import os, shutil


auth = Blueprint('auth', __name__)

if os.path.exists('/mnt/hdd/mynode/'):
    HOME_DIR = str('/mnt/hdd/mynode/pleb-vpn')
    EXEC_DIR = str('/opt/mynode/pleb-vpn')
if os.path.exists('/mnt/hdd/raspiblitz.conf'):
    HOME_DIR = str('/mnt/hdd/app-data/pleb-vpn')
    EXEC_DIR = str('/home/admin/pleb-vpn')

@auth.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        user_name = request.form.get('user_name')
        password = request.form.get('password')

        user = User.query.filter_by(user_name=user_name).first()
        if user:
            if check_password_hash(user.password, password):
                flash('Logged in successfully!', category='success')
                login_user(user, remember=True)
                return redirect(url_for('views.home'))
            else:
                flash('Incorrect password, try again.', category='error')
        else:
            flash('User name does not exist.', category='error')
        
    return render_template("login.html", user=current_user)

@auth.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('auth.login'))

@auth.route('/change_password', methods=['GET', 'POST'])
@login_required
def change_password():
    global plebVPN_status
    if request.method == 'POST':
        password1 = request.form.get('password1')
        password2 = request.form.get('password2')
        if password1 != password2:
            flash('Passwords don\'t match.', category='error')
        elif len(password1) < 7:
            flash('Password must be at least 7 characters.', category='error')
        else:
            newHash = generate_password_hash(password1, method='sha256')
            User.query.filter_by(id=current_user.id).update(dict(password=newHash))
            db.session.commit() 
            # copy database to HOME_DIR so new password survives updates and reflashes
            if os.path.exists(os.path.join(HOME_DIR, 'instance')):
                shutil.rmtree(os.path.join(HOME_DIR, 'instance'))
            shutil.copytree(os.path.join(EXEC_DIR, 'instance'), HOME_DIR)
            flash('Password changed successfully!', category='success')
            return redirect(url_for('views.home'))
    
    return render_template("change_password.html", user=current_user)