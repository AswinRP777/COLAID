from flask import Flask, request, send_file, jsonify
import cv2
import os
from daltonize import daltonize
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from models import db, User
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'fallback_secret')
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'colaid.db')

db.init_app(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

with app.app_context():
    db.create_all()

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
@app.route("/", methods=["GET"])
def test():
    print("🔥 PHONE REACHED BACKEND")
    return "Backend reachable"

@app.route("/daltonize", methods=["POST"])
def daltonize_api():
    print("Request received")   

    if "image" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    defect = request.form.get("defect", "protanopia")
    print("Defect:", defect)     

    file = request.files["image"]
    input_path = os.path.join(UPLOAD_FOLDER, "input.png")
    output_path = os.path.join(UPLOAD_FOLDER, "output.png")

    file.save(input_path)
    print(f"Image saved to {input_path}")         

    img = cv2.imread(input_path)
    if img is None:
        print("❌ Error: cv2.imread returned None. Image might be corrupt or invalid format.")
        return jsonify({"error": "Invalid image format"}), 400
    
    print(f"Image shape: {img.shape}")

    print("Starting processing")
    try:
        result = daltonize(img, defect)
    except Exception as e:
        print(f"❌ Error during daltonize: {e}")
        return jsonify({"error": str(e)}), 500
        
    print("Processing done")     

    cv2.imwrite(output_path, result)
    if not os.path.exists(output_path):
         print("❌ Error: Output file was not written.")
         return jsonify({"error": "Processing failed to save output"}), 500

    print(f"Image written to {output_path}, Size: {os.path.getsize(output_path)} bytes")       

    return send_file(output_path, mimetype="image/png")


@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({"error": "Username already exists"}), 400

    new_user = User(username=username)
    new_user.set_password(password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "User registered successfully"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    user = User.query.filter_by(username=username).first()

    if user and user.check_password(password):
        login_user(user)
        return jsonify({"message": "Login successful"}), 200
    
    return jsonify({"error": "Invalid credentials"}), 401

@app.route('/logout', methods=['POST'])
@login_required
def logout():
    logout_user()
    return jsonify({"message": "Logged out successfully"}), 200

@app.route('/reset-password', methods=['POST'])
@login_required
def reset_password():
    data = request.get_json()
    new_password = data.get('new_password')

    if not new_password or len(new_password) < 6:
        return jsonify({"error": "Password must be at least 6 characters"}), 400

    # current_user is available because of @login_required
    current_user.set_password(new_password)
    db.session.commit()

    return jsonify({"message": "Password updated successfully"}), 200

@app.route('/delete-account', methods=['POST'])
@login_required
def delete_account():
    try:
        db.session.delete(current_user)
        db.session.commit()
        logout_user()
        return jsonify({"message": "Account deleted successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@app.route('/guest-login', methods=['POST'])
def guest_login():
    guest_user = User.query.filter_by(username='Guest').first()
    
    if not guest_user:
        # Create a Guest user with a random high-entropy password
        import secrets
        guest_user = User(username='Guest')
        guest_user.set_password(secrets.token_hex(16))
        db.session.add(guest_user)
        db.session.commit()
    
    login_user(guest_user)
    return jsonify({"message": "Logged in as Guest", "username": "Guest"}), 200



if __name__ == "__main__":
    port = int(os.getenv('FLASK_PORT', 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
