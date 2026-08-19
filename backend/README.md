# Library Management System

A robust Library Management Application with WhatsApp notifications for membership expiry.

## Features
- **Student Management**: Add, list, and view student details.
- **SQLite Database**: Persistent storage for all student data.
- **WhatsApp Integration**: Automatically send registration and expiry reminder messages via Twilio WhatsApp API.
- **Automatic Expiry Tracking**: Identify expired memberships and send reminders.
- **Web Interface**: Responsive Bootstrap-based UI.

## Tech Stack
- **Backend**: Python with Flask and SQLAlchemy
- **Frontend**: HTML5, Bootstrap 5
- **Database**: SQLite
- **WhatsApp API**: Twilio

## Prerequisites
- Python 3.x
- Twilio Account (for WhatsApp integration)

## Setup & Installation

### 1. Clone the repository (if applicable)
Ensure you have the backend folder.

### 2. Set up a Virtual Environment
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```
*(Note: I have already prepared the environment for you in `flask_env`)*

### 3. Configure Environment Variables
You must set your Twilio credentials to enable WhatsApp messaging. Replace the placeholders in `app.py` or set them in your environment:

```bash
export TWILIO_ACCOUNT_SID='your_account_sid'
export TWILIO_AUTH_TOKEN='your_auth_token'
export TWILIO_WHATSAPP_NUMBER='whatsapp:+14155238886'
export ADMIN_PHONE_NUMBER='whatsapp:+919999999999'
```

### 4. Run the Application
```bash
python app.py
```
Access the app at `http://127.0.0.1:5000`

## Usage
- **Add Student**: Go to "Add Student" and fill in the form. Upon submission, a WhatsApp message is triggered.
- **View Students**: See all registered students and their current status.
- **Reminders**: Access the "Send Expiry Reminder" feature to notify students whose membership is ending.

---
*Developed by Claude AI*