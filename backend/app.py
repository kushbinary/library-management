"""
Library Management Application - Backend API

Features:
- Student registration with admission details
- SQLite database persistence
- WhatsApp integration via Twilio
- Cron jobs for expired admission notifications
- REST API endpoints
"""

import os
import datetime
from flask import Flask, jsonify, request, render_template, flash, redirect, url_for, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from twilio.rest import Client

# Load environment variables
TWILIO_ACCOUNT_SID = os.environ.get('TWILIO_ACCOUNT_SID', 'your_twilio_account_sid_here')
TWILIO_AUTH_TOKEN = os.environ.get('TWILIO_AUTH_TOKEN', 'your_twilio_auth_token_here')
TWILIO_WHATSAPP_NUMBER = os.environ.get('TWILIO_WHATSAPP_NUMBER', 'whatsapp:+14155238886')
ADMIN_PHONE_NUMBER = os.environ.get('ADMIN_PHONE_NUMBER', 'whatsapp:+919999999999')

app = Flask(__name__, template_folder='templates', static_folder='static')
app.config['SECRET_KEY'] = 'dev-secret-key-change-in-production'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///library.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
CORS(app)
db = SQLAlchemy(app)

# ==================== Database Models ====================

# Library settings - total seat capacity
LIBRARY_CONFIG = {'total_seats': 50}  # Adjust as needed

class Student(db.Model):
    __tablename__ = 'students'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    admission_date = db.Column(db.Date, nullable=False, default=datetime.date.today)
    timing = db.Column(db.String(50), nullable=False)
    seat_number = db.Column(db.String(20), nullable=False, unique=True)
    expiry_date = db.Column(db.Date, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.datetime.utcnow)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'phone': self.phone,
            'admission_date': self.admission_date.strftime('%Y-%m-%d') if self.admission_date else None,
            'timing': self.timing,
            'seat_number': self.seat_number,
            'expiry_date': self.expiry_date.strftime('%Y-%m-%d') if self.expiry_date else None,
            'days_remaining': self.days_remaining(),
            'is_expired': self.is_expired(),
            'seat_status': self.get_seat_status()
        }

    def get_seat_status(self):
        """Returns seat availability status"""
        filled_seats = len(Student.query.all())
        total = LIBRARY_CONFIG['total_seats']
        return {'filled': filled_seats, 'total': total, 'available': total - filled_seats}

    def days_remaining(self):
        if self.expiry_date:
            delta = (self.expiry_date - datetime.date.today()).days
            return max(0, delta)
        return 0

    def is_expired(self):
        if self.expiry_date:
            return datetime.date.today() > self.expiry_date
        return False


# ==================== WhatsApp Service ====================

def send_whatsapp_message(student_name, student_phone, message_type='registration'):
    """
    Send WhatsApp message via Twilio
    Requires valid Twilio Account SID, Auth Token, and WhatsApp number
    """
    # In production, uncomment below:
    # client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
    # client.messages.create(
    #     body=message,
    #     from_=TWILIO_WHATSAPP_NUMBER,
    #     to=f'whatsapp:+91{student_phone}'
    # )

    # Development mode - log message
    if message_type == 'registration':
        message = (
            f"🌟 नई लाइब्रेरी रजिस्ट्रेशन 🎉\n\n"
            f"नमस्त्र, {student_name}!\n"
            f"आपका लाइब्रेरी मेंबरशिप सफलतापूर्वक रजिस्टर हो गई है।\n\n"
            f"अपना सम्मान: एक धन्यवाद! 🙏"
        )
    elif message_type == 'expiry_warning':
        message = (
            f"⚠️ लाइब्रेरी मेम्बरशिप समाप्ति सूचना ⚠️\n\n"
            f"नमस्त्र,\n"
            f"आपका लाइब्रेरी मेम्बरशिप {datetime.date.today().strftime('%d %B %Y')} को समाप्त हो रहा है।\n"
            f"कृपया नए से आवंटित करने के लिए संपर्क करें।\n\n"
            f"धन्यवाद! 🙏"
        )

    # Print message for development/testing
    print(f"[WHATSAPP MESSAGE SENT]\nTo: {student_phone}\nType: {message_type}\nMessage:\n{message}\n")
    return f"Message sent to {student_phone}"


# ==================== Routes - Frontend & APK ====================

@app.route('/')
def index():
    return render_template('index.html')


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
    return "APK not found on server", 404


@app.route('/download/MyLibbook.apk')
def download_mylibbook_apk():
    static_dir = os.path.join(app.root_path, 'static')
    if os.path.exists(os.path.join(static_dir, 'MyLibbook_v1.0.apk')):
        return send_from_directory(static_dir, 'MyLibbook_v1.0.apk', as_attachment=True, download_name='MyLibbook_v1.0.apk')
    parent_dir = os.path.abspath(os.path.join(app.root_path, '..'))
    if os.path.exists(os.path.join(parent_dir, 'MyLibbook_v1.0.apk')):
        return send_from_directory(parent_dir, 'MyLibbook_v1.0.apk', as_attachment=True, download_name='MyLibbook_v1.0.apk')
    return "APK not found on server", 404



@app.route('/students')
def student_list():
    students = Student.query.order_by(Student.created_at.desc()).all()
    return render_template('students.html', students=students)


@app.route('/add_student', methods=['GET', 'POST'])
def add_student():
    if request.method == 'POST':
        name = request.form.get('name')
        email = request.form.get('email')
        phone = request.form.get('phone')
        admission_date_str = request.form.get('admission_date')
        timing = request.form.get('timing')
        seat_number = request.form.get('seat_number')
        expiry_date_str = request.form.get('expiry_date')

        admission_date = datetime.datetime.strptime(admission_date_str, '%Y-%m-%d').date()
        expiry_date = datetime.datetime.strptime(expiry_date_str, '%Y-%m-%d').date()

        student = Student(
            name=name,
            email=email,
            phone=phone,
            admission_date=admission_date,
            timing=timing,
            seat_number=seat_number,
            expiry_date=expiry_date
        )
        db.session.add(student)
        db.session.commit()

        # Send WhatsApp registration message
        send_whatsapp_message(name, phone, 'registration')

        flash('Student registered successfully!', 'success')
        return redirect(url_for('student_list'))

    return render_template('add_student.html')


@app.route('/student/<int:student_id>')
def view_student(student_id):
    student = db.get_or_404(Student, student_id)
    return render_template('student_profile.html', student=student)


@app.route('/student/<int:student_id>/send_reminder')
def send_reminder(student_id):
    student = db.get_or_404(Student, student_id)
    if student.is_expired():
        send_whatsapp_message(student.name, student.phone, 'expiry_warning')
        flash(f'Expiry reminder sent to {student.name}!')
    else:
        flash(f'{student.name} membership has not expired yet!')
    return redirect(url_for('view_student', student_id=student_id))


# ==================== API Routes ====================

@app.route('/api/students', methods=['GET'])
def api_get_students():
    students = Student.query.order_by(Student.created_at.desc()).all()
    return jsonify([s.to_dict() for s in students])


@app.route('/api/students', methods=['POST'])
def api_add_student():
    data = request.json
    required_fields = ['name', 'email', 'phone', 'admission_date', 'timing', 'seat_number', 'expiry_date']
    missing = [f for f in required_fields if not data.get(f)]

    if missing:
        return jsonify({'error': f'Missing required fields: {", ".join(missing)}'}), 400

    try:
        admission_date = datetime.datetime.strptime(data['admission_date'], '%Y-%m-%d').date()
        expiry_date = datetime.datetime.strptime(data['expiry_date'], '%Y-%m-%d').date()
    except ValueError:
        return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD.'}), 400

    student = Student(
        name=data['name'],
        email=data['email'],
        phone=data['phone'],
        admission_date=admission_date,
        timing=data['timing'],
        seat_number=data['seat_number'],
        expiry_date=expiry_date
    )
    db.session.add(student)
    db.session.commit()

    send_whatsapp_message(student.name, student.phone, 'registration')
    return jsonify({'message': 'Student registered!', 'student': student.to_dict()}), 201


@app.route('/api/expired_students', methods=['GET'])
def api_get_expired_students():
    today = datetime.date.today()
    expired = Student.query.filter(Student.expiry_date <= today).all()
    return jsonify([s.to_dict() for s in expired])


@app.route('/api/send_expiry_notifications', methods=['POST'])
def api_send_expiry_notifications():
    today = datetime.date.today()
    expired = Student.query.filter(Student.expiry_date <= today).all()
    for student in expired:
        send_whatsapp_message(student.name, student.phone, 'expiry_warning')
    return jsonify({'message': f'Sent notifications to {len(expired)} expired memberships.'})


# ==================== Scheduled Task ====================

@app.route('/cron/send_expired_notifications')
def cron_send_expired_notifications():
    """This endpoint can be called by a cron job to send expired notifications daily"""
    return api_send_expiry_notifications()


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000, debug=True)