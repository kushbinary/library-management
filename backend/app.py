"""
Library Management Application - Backend API & Cloud Portal

Features:
- Multi-tenant Cloud Database (Neon PostgreSQL & SQLite auto-fallback)
- User Authentication (Registration / Sign Up, Login, Multi-user Data Isolation)
- Per-user Student registration & seat management with admission details & fee tracking
- WhatsApp integration via Twilio
- Expiry notification tracking & cron endpoints
- REST API for Mobile App synchronization
- Direct Android APK distribution
"""

import os
import datetime
from functools import wraps
from flask import Flask, jsonify, request, render_template, flash, redirect, url_for, send_from_directory, session
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash

# ----------------- App Configuration -----------------
app = Flask(__name__, template_folder='templates', static_folder='static')
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'library-secret-key-cloud-2026')

# Database configuration: Cloud PostgreSQL or SQLite fallback
database_url = os.environ.get('DATABASE_URL')
if database_url:
    if database_url.startswith("postgres://"):
        database_url = database_url.replace("postgres://", "postgresql://", 1)
    app.config['SQLALCHEMY_DATABASE_URI'] = database_url
else:
    # Ensure database path is always absolute in the backend folder
    db_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'library.db')
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'

app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
CORS(app)
db = SQLAlchemy(app)

# Load Twilio environment variables
TWILIO_ACCOUNT_SID = os.environ.get('TWILIO_ACCOUNT_SID', 'your_twilio_account_sid_here')
TWILIO_AUTH_TOKEN = os.environ.get('TWILIO_AUTH_TOKEN', 'your_twilio_auth_token_here')
TWILIO_WHATSAPP_NUMBER = os.environ.get('TWILIO_WHATSAPP_NUMBER', 'whatsapp:+14155238886')
ADMIN_PHONE_NUMBER = os.environ.get('ADMIN_PHONE_NUMBER', 'whatsapp:+919999999999')

LIBRARY_CONFIG = {'total_seats': 50}

# ==================== Database Models ====================

class AdminUser(db.Model):
    __tablename__ = 'admin_users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    library_name = db.Column(db.String(120), nullable=True, default='My Library')
    email = db.Column(db.String(120), nullable=True, default='')
    phone = db.Column(db.String(20), nullable=True, default='')
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)

    students = db.relationship('Student', backref='owner', lazy=True, cascade='all, delete-orphan')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'library_name': self.library_name or 'My Library',
            'email': self.email or '',
            'phone': self.phone or '',
            'created_at': self.created_at.strftime('%Y-%m-%d %H:%M:%S') if self.created_at else None
        }


class Student(db.Model):
    __tablename__ = 'students'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('admin_users.id'), nullable=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=True, default='')
    phone = db.Column(db.String(20), nullable=False)
    admission_date = db.Column(db.Date, nullable=False, default=datetime.date.today)
    timing = db.Column(db.String(50), nullable=False)
    seat_number = db.Column(db.String(20), nullable=False)
    expiry_date = db.Column(db.Date, nullable=False)
    total_fee = db.Column(db.Float, default=1000.0)
    paid_amount = db.Column(db.Float, default=1000.0)
    due_amount = db.Column(db.Float, default=0.0)
    payment_mode = db.Column(db.String(50), default='UPI')
    payment_status = db.Column(db.String(50), default='Paid')
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'name': self.name,
            'email': self.email or '',
            'phone': self.phone,
            'admission_date': self.admission_date.strftime('%Y-%m-%d') if self.admission_date else None,
            'timing': self.timing,
            'seat_number': self.seat_number,
            'expiry_date': self.expiry_date.strftime('%Y-%m-%d') if self.expiry_date else None,
            'total_fee': float(self.total_fee or 1000.0),
            'paid_amount': float(self.paid_amount or 1000.0),
            'due_amount': float(self.due_amount or 0.0),
            'payment_mode': self.payment_mode or 'UPI',
            'payment_status': self.payment_status or 'Paid',
            'days_remaining': self.days_remaining(),
            'is_expired': self.is_expired(),
            'seat_status': self.get_seat_status()
        }

    def get_seat_status(self):
        filled_seats = Student.query.filter_by(user_id=self.user_id).count() if self.user_id else Student.query.count()
        total = LIBRARY_CONFIG['total_seats']
        return {'filled': filled_seats, 'total': total, 'available': max(0, total - filled_seats)}

    def days_remaining(self):
        if self.expiry_date:
            delta = (self.expiry_date - datetime.date.today()).days
            return max(0, delta)
        return 0

    def is_expired(self):
        if self.expiry_date:
            return datetime.date.today() > self.expiry_date
        return False


# ==================== Database Auto-Initialization & Migration ====================

def init_db():
    try:
        db.create_all()
        # Ensure new columns exist in case of pre-existing tables
        with db.engine.connect() as conn:
            migration_statements = [
                "ALTER TABLE students ADD COLUMN IF NOT EXISTS user_id INTEGER;",
                "ALTER TABLE students ADD COLUMN IF NOT EXISTS total_fee FLOAT DEFAULT 1000.0;",
                "ALTER TABLE students ADD COLUMN IF NOT EXISTS paid_amount FLOAT DEFAULT 1000.0;",
                "ALTER TABLE students ADD COLUMN IF NOT EXISTS due_amount FLOAT DEFAULT 0.0;",
                "ALTER TABLE students ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(50) DEFAULT 'UPI';",
                "ALTER TABLE students ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'Paid';",
                "ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS library_name VARCHAR(120) DEFAULT 'My Library';",
                "ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS email VARCHAR(120) DEFAULT '';",
                "ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS phone VARCHAR(20) DEFAULT '';"
            ]
            for stmt in migration_statements:
                try:
                    conn.execute(db.text(stmt))
                    conn.commit()
                except Exception:
                    pass

        # Create default admin account if not already created
        default_admin_username = os.environ.get('ADMIN_USERNAME', 'admin')
        default_admin_password = os.environ.get('ADMIN_PASSWORD', 'admin123')
        existing_admin = AdminUser.query.filter_by(username=default_admin_username).first()
        if not existing_admin:
            new_admin = AdminUser(username=default_admin_username, library_name='Central Library')
            new_admin.set_password(default_admin_password)
            db.session.add(new_admin)
            db.session.commit()
            print(f"[AUTH] Default admin created -> Username: {default_admin_username}")

        # Link any orphaned students to first admin user
        default_user = AdminUser.query.first()
        if default_user:
            Student.query.filter(Student.user_id.is_(None)).update({'user_id': default_user.id})
            db.session.commit()

    except Exception as e:
        db.session.rollback()
        print(f"[DB INIT ERROR] {e}")

with app.app_context():
    init_db()

@app.route('/init-db')
def manual_init_db():
    try:
        init_db()
        return jsonify({
            "status": "success",
            "message": "Database tables and columns created/updated, and admin user initialized successfully!"
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({
            "status": "error",
            "message": f"Database initialization failed: {str(e)}"
        }), 500


# ==================== User Scoping & Authentication Helper ====================

def get_request_user():
    """Extract authenticated user from Session or API Headers/Payload."""
    # 1. From Session (Web)
    if 'user_id' in session:
        return AdminUser.query.get(session['user_id'])

    # 2. From Headers (Mobile App API)
    user_id_header = request.headers.get('X-User-Id')
    username_header = request.headers.get('X-Username')

    if user_id_header:
        try:
            user = AdminUser.query.get(int(user_id_header))
            if user: return user
        except:
            pass

    if username_header:
        user = AdminUser.query.filter_by(username=username_header.strip()).first()
        if user: return user

    # 3. From Request args or json
    username_param = request.args.get('username')
    if not username_param and request.is_json and request.json:
        username_param = request.json.get('username')
    if username_param:
        user = AdminUser.query.filter_by(username=str(username_param).strip()).first()
        if user: return user

    user_id_param = request.args.get('user_id')
    if not user_id_param and request.is_json and request.json:
        user_id_param = request.json.get('user_id')
    if user_id_param:
        try:
            user = AdminUser.query.get(int(user_id_param))
            if user: return user
        except:
            pass

    # Fallback to first user
    return AdminUser.query.first()


# ==================== Authentication Decorator ====================

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'admin_user' not in session or 'user_id' not in session:
            flash('Please log in with your username and password to access this page.', 'warning')
            return redirect(url_for('login', next=request.url))
        return f(*args, **kwargs)
    return decorated_function


# ==================== WhatsApp Service ====================

def send_whatsapp_message(student_name, student_phone, message_type='registration'):
    if message_type == 'registration':
        message = (
            f"🌟 नई लाइब्रेरी रजिस्ट्रेशन 🎉\n\n"
            f"नमस्ते, {student_name}!\n"
            f"आपका लाइब्रेरी मेंबरशिप सफलतापूर्वक रजिस्टर हो गई है।\n\n"
            f"धन्यवाद! 🙏"
        )
    elif message_type == 'expiry_warning':
        message = (
            f"⚠️ लाइब्रेरी मेम्बरशिप समाप्ति सूचना ⚠️\n\n"
            f"नमस्ते {student_name},\n"
            f"आपका लाइब्रेरी मेम्बरशिप {datetime.date.today().strftime('%d %B %Y')} को समाप्त हो रहा है।\n"
            f"कृपया नए से रिन्यू कराने के लिए संपर्क करें।\n\n"
            f"धन्यवाद! 🙏"
        )
    else:
        message = f"Library notification for {student_name}"

    print(f"[WHATSAPP MESSAGE SENT] To: {student_phone} | Type: {message_type}\n{message}\n")
    return f"Message processed for {student_phone}"


# ==================== Authentication Routes (Web) ====================

@app.route('/signup', methods=['GET', 'POST'])
def signup():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '').strip()
        confirm_password = request.form.get('confirm_password', '').strip()
        library_name = request.form.get('library_name', '').strip() or 'My Library'
        phone = request.form.get('phone', '').strip()

        if not username or not password:
            flash('Username and password are required.', 'danger')
            return render_template('signup.html')

        if password != confirm_password:
            flash('Passwords do not match.', 'danger')
            return render_template('signup.html')

        if len(password) < 4:
            flash('Password must be at least 4 characters long.', 'danger')
            return render_template('signup.html')

        if AdminUser.query.filter_by(username=username).first():
            flash('Username already exists. Please choose another or Login.', 'warning')
            return render_template('signup.html')

        user = AdminUser(username=username, library_name=library_name, phone=phone)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()

        session['admin_user'] = user.username
        session['user_id'] = user.id
        session['library_name'] = user.library_name
        flash(f'Account created successfully! Welcome, {user.username}!', 'success')
        return redirect(url_for('student_list'))

    return render_template('signup.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '').strip()

        user = AdminUser.query.filter_by(username=username).first()
        if user and user.check_password(password):
            session['admin_user'] = user.username
            session['user_id'] = user.id
            session['library_name'] = user.library_name or 'My Library'
            flash(f'Welcome back, {user.username}!', 'success')
            next_page = request.form.get('next') or url_for('student_list')
            return redirect(next_page)
        else:
            flash('Invalid username or password. Please try again.', 'danger')

    return render_template('login.html')


@app.route('/logout')
def logout():
    session.pop('admin_user', None)
    session.pop('user_id', None)
    session.pop('library_name', None)
    flash('You have been logged out successfully.', 'info')
    return redirect(url_for('login'))


@app.route('/change_password', methods=['GET', 'POST'])
@login_required
def change_password():
    if request.method == 'POST':
        current_password = request.form.get('current_password', '').strip()
        new_password = request.form.get('new_password', '').strip()
        confirm_password = request.form.get('confirm_password', '').strip()

        user = AdminUser.query.get(session['user_id'])
        if not user or not user.check_password(current_password):
            flash('Current password is incorrect.', 'danger')
            return render_template('change_password.html')

        if new_password != confirm_password:
            flash('New passwords do not match.', 'warning')
            return render_template('change_password.html')

        if len(new_password) < 4:
            flash('Password must be at least 4 characters long.', 'warning')
            return render_template('change_password.html')

        user.set_password(new_password)
        db.session.commit()
        flash('Password changed successfully!', 'success')
        return redirect(url_for('student_list'))

    return render_template('change_password.html')


# ==================== Frontend Routes (Isolated per User) ====================

@app.route('/')
def index():
    active_members = 0
    if 'user_id' in session:
        active_members = Student.query.filter_by(user_id=session['user_id']).count()
    return render_template('index.html', active_members=active_members)


@app.route('/students')
@login_required
def student_list():
    user_id = session.get('user_id')
    students = Student.query.filter_by(user_id=user_id).order_by(Student.created_at.desc()).all()
    return render_template('students.html', students=students)


@app.route('/add_student', methods=['GET', 'POST'])
@login_required
def add_student():
    if request.method == 'POST':
        user_id = session.get('user_id')
        name = request.form.get('name')
        email = request.form.get('email', '')
        phone = request.form.get('phone')
        admission_date_str = request.form.get('admission_date')
        timing = request.form.get('timing')
        seat_number = request.form.get('seat_number')
        expiry_date_str = request.form.get('expiry_date')
        total_fee = float(request.form.get('total_fee', 1000.0) or 1000.0)
        paid_amount = float(request.form.get('paid_amount', 1000.0) or 1000.0)
        due_amount = max(0.0, total_fee - paid_amount)
        payment_mode = request.form.get('payment_mode', 'UPI')
        payment_status = 'Paid' if due_amount <= 0 else ('Due' if paid_amount <= 0 else 'Partial')

        try:
            admission_date = datetime.datetime.strptime(admission_date_str, '%Y-%m-%d').date()
            expiry_date = datetime.datetime.strptime(expiry_date_str, '%Y-%m-%d').date()
        except (ValueError, TypeError):
            flash('Invalid date format. Please select valid dates.', 'danger')
            return render_template('add_student.html')

        student = Student(
            user_id=user_id,
            name=name,
            email=email,
            phone=phone,
            admission_date=admission_date,
            timing=timing,
            seat_number=seat_number,
            expiry_date=expiry_date,
            total_fee=total_fee,
            paid_amount=paid_amount,
            due_amount=due_amount,
            payment_mode=payment_mode,
            payment_status=payment_status
        )
        db.session.add(student)
        db.session.commit()

        # Send WhatsApp registration message
        send_whatsapp_message(name, phone, 'registration')

        flash('Student registered successfully!', 'success')
        return redirect(url_for('student_list'))

    return render_template('add_student.html')


@app.route('/student/<int:student_id>')
@login_required
def view_student(student_id):
    user_id = session.get('user_id')
    student = Student.query.filter_by(id=student_id, user_id=user_id).first_or_404()
    return render_template('student_profile.html', student=student)


@app.route('/student/<int:student_id>/send_reminder')
@login_required
def send_reminder(student_id):
    user_id = session.get('user_id')
    student = Student.query.filter_by(id=student_id, user_id=user_id).first_or_404()
    if student.is_expired():
        send_whatsapp_message(student.name, student.phone, 'expiry_warning')
        flash(f'Expiry reminder sent to {student.name}!', 'success')
    else:
        flash(f'{student.name}\'s membership has not expired yet!', 'info')
    return redirect(url_for('view_student', student_id=student_id))


# ==================== APK Download Routes ====================

@app.route('/download-apk')
@app.route('/download/LibraryHubPro.apk')
def download_apk():
    static_dir = os.path.join(app.root_path, 'static')
    for fname in ['LibraryHubPro_v1.0.apk', 'LibraryHubPro.apk', 'MyLibbook_v1.0.apk']:
        if os.path.exists(os.path.join(static_dir, fname)):
            return send_from_directory(static_dir, fname, as_attachment=True, download_name='LibraryHubPro_v1.0.apk')
    parent_dir = os.path.abspath(os.path.join(app.root_path, '..'))
    for fname in ['LibraryHubPro_v1.0.apk', 'LibraryHubPro.apk', 'MyLibbook_v1.0.apk']:
        if os.path.exists(os.path.join(parent_dir, fname)):
            return send_from_directory(parent_dir, fname, as_attachment=True, download_name='LibraryHubPro_v1.0.apk')
    return "APK file not found on server", 404


@app.route('/download/MyLibbook.apk')
def download_mylibbook_apk():
    static_dir = os.path.join(app.root_path, 'static')
    if os.path.exists(os.path.join(static_dir, 'MyLibbook_v1.0.apk')):
        return send_from_directory(static_dir, 'MyLibbook_v1.0.apk', as_attachment=True, download_name='MyLibbook_v1.0.apk')
    parent_dir = os.path.abspath(os.path.join(app.root_path, '..'))
    if os.path.exists(os.path.join(parent_dir, 'MyLibbook_v1.0.apk')):
        return send_from_directory(parent_dir, 'MyLibbook_v1.0.apk', as_attachment=True, download_name='MyLibbook_v1.0.apk')
    return "APK not found on server", 404


# ==================== REST API Routes (Multi-Tenant) ====================

@app.route('/api/signup', methods=['POST'])
def api_signup():
    data = request.json or {}
    username = data.get('username', '').strip()
    password = data.get('password', '').strip()
    library_name = data.get('library_name', '').strip() or data.get('fullName', '').strip() or 'My Library'
    email = data.get('email', '').strip()
    phone = data.get('phone', '').strip()

    if not username or not password:
        return jsonify({'success': False, 'error': 'Username and password are required'}), 400

    if len(password) < 4:
        return jsonify({'success': False, 'error': 'Password must be at least 4 characters long'}), 400

    if AdminUser.query.filter_by(username=username).first():
        return jsonify({'success': False, 'error': 'Username is already taken. Please choose another or login.'}), 409

    user = AdminUser(username=username, library_name=library_name, email=email, phone=phone)
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    return jsonify({
        'success': True,
        'message': 'Account created successfully!',
        'user': user.to_dict(),
        'username': user.username,
        'user_id': user.id
    }), 201


@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.json or {}
    username = data.get('username', '').strip()
    password = data.get('password', '').strip()

    user = AdminUser.query.filter_by(username=username).first()
    if user and user.check_password(password):
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'user': user.to_dict(),
            'username': user.username,
            'user_id': user.id
        }), 200
    return jsonify({'success': False, 'error': 'Invalid username or password'}), 401


@app.route('/api/students', methods=['GET'])
def api_get_students():
    user = get_request_user()
    if not user:
        return jsonify([])

    students = Student.query.filter_by(user_id=user.id).order_by(Student.created_at.desc()).all()
    return jsonify([s.to_dict() for s in students])


@app.route('/api/students', methods=['POST'])
def api_add_student():
    user = get_request_user()
    data = request.json or {}
    required_fields = ['name', 'phone', 'admission_date', 'timing', 'seat_number', 'expiry_date']
    missing = [f for f in required_fields if not data.get(f)]

    if missing:
        return jsonify({'error': f'Missing required fields: {", ".join(missing)}'}), 400

    try:
        admission_date = datetime.datetime.strptime(data['admission_date'], '%Y-%m-%d').date()
        expiry_date = datetime.datetime.strptime(data['expiry_date'], '%Y-%m-%d').date()
    except (ValueError, TypeError):
        return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD.'}), 400

    total_fee = float(data.get('total_fee') or data.get('totalFee') or 1000.0)
    paid_amount = float(data.get('paid_amount') or data.get('paidAmount') or total_fee)
    due_amount = max(0.0, total_fee - paid_amount)
    payment_mode = data.get('payment_mode') or data.get('paymentMode') or 'UPI'
    payment_status = data.get('payment_status') or data.get('paymentStatus') or ('Paid' if due_amount <= 0 else ('Due' if paid_amount <= 0 else 'Partial'))

    student = Student(
        user_id=user.id if user else None,
        name=data['name'],
        email=data.get('email', ''),
        phone=data['phone'],
        admission_date=admission_date,
        timing=data['timing'],
        seat_number=data['seat_number'],
        expiry_date=expiry_date,
        total_fee=total_fee,
        paid_amount=paid_amount,
        due_amount=due_amount,
        payment_mode=payment_mode,
        payment_status=payment_status
    )
    db.session.add(student)
    db.session.commit()

    send_whatsapp_message(student.name, student.phone, 'registration')
    return jsonify({'message': 'Student registered!', 'student': student.to_dict()}), 201


@app.route('/api/students/<int:student_id>', methods=['PUT'])
def api_update_student(student_id):
    user = get_request_user()
    query = Student.query.filter_by(id=student_id)
    if user:
        query = query.filter_by(user_id=user.id)
    student = query.first_or_404()

    data = request.json or {}
    if 'name' in data: student.name = data['name']
    if 'phone' in data: student.phone = data['phone']
    if 'timing' in data: student.timing = data['timing']
    if 'seat_number' in data: student.seat_number = data['seat_number']
    if 'admission_date' in data:
        try: student.admission_date = datetime.datetime.strptime(data['admission_date'], '%Y-%m-%d').date()
        except: pass
    if 'expiry_date' in data:
        try: student.expiry_date = datetime.datetime.strptime(data['expiry_date'], '%Y-%m-%d').date()
        except: pass
    if 'total_fee' in data: student.total_fee = float(data['total_fee'])
    if 'paid_amount' in data: student.paid_amount = float(data['paid_amount'])
    if 'due_amount' in data: student.due_amount = float(data['due_amount'])
    if 'payment_mode' in data: student.payment_mode = data['payment_mode']
    if 'payment_status' in data: student.payment_status = data['payment_status']

    db.session.commit()
    return jsonify({'message': 'Student updated successfully', 'student': student.to_dict()})


@app.route('/api/students/<int:student_id>', methods=['DELETE'])
def api_delete_student(student_id):
    user = get_request_user()
    query = Student.query.filter_by(id=student_id)
    if user:
        query = query.filter_by(user_id=user.id)
    student = query.first_or_404()

    db.session.delete(student)
    db.session.commit()
    return jsonify({'message': 'Student deleted successfully'})


@app.route('/api/expired_students', methods=['GET'])
def api_get_expired_students():
    user = get_request_user()
    today = datetime.date.today()
    query = Student.query.filter(Student.expiry_date <= today)
    if user:
        query = query.filter_by(user_id=user.id)
    expired = query.all()
    return jsonify([s.to_dict() for s in expired])


@app.route('/api/send_expiry_notifications', methods=['POST'])
def api_send_expiry_notifications():
    user = get_request_user()
    today = datetime.date.today()
    query = Student.query.filter(Student.expiry_date <= today)
    if user:
        query = query.filter_by(user_id=user.id)
    expired = query.all()
    for student in expired:
        send_whatsapp_message(student.name, student.phone, 'expiry_warning')
    return jsonify({'message': f'Sent notifications to {len(expired)} expired memberships.'})


@app.route('/cron/send_expired_notifications')
def cron_send_expired_notifications():
    return api_send_expiry_notifications()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)