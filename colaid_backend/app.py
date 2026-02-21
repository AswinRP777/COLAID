from flask import Flask, request, send_file, jsonify, after_this_request
import cv2
import os
import gc
import uuid
from daltonize import daltonize
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from pymongo import MongoClient
from bson import ObjectId
from models import User
from dotenv import load_dotenv
import certifi

load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'fallback_secret')

# MongoDB Atlas connection
mongo_client = MongoClient(
    os.getenv("MONGODB_URI"),
    tls=True,
    tlsCAFile=certifi.where()
)
try:
    db = mongo_client.get_default_database()  # Uses database from connection string
except Exception:
    db = mongo_client.get_database('colaid')  # Fallback to 'colaid' database
try:
    db.list_collection_names()
    print("MongoDB connected to DB ✅")
except Exception as e:
    print("MongoDB error ❌", e)


login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

@login_manager.user_loader
def load_user(user_id):
    try:
        user_data = db.users.find_one({'_id': ObjectId(user_id)})
        if user_data:
            return User(user_data)
    except:
        pass
    return None

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.route("/", methods=["GET"])
def test():
    print("🔥 PHONE REACHED BACKEND")
    return "Backend reachable"

@app.route("/mongo-test")
def mongo_test():
    mongo_client.admin.command("ping")
    return "MongoDB connected ✅"


@app.route("/daltonize", methods=["POST"])
def daltonize_api():
    print("Request received")   

    if "image" not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    defect = request.form.get("defect", "protanopia")
    print("Defect:", defect)     

    # Use unique filenames to prevent concurrent request collisions
    request_id = uuid.uuid4().hex[:8]
    input_path = os.path.join(UPLOAD_FOLDER, f"input_{request_id}.png")
    output_path = os.path.join(UPLOAD_FOLDER, f"output_{request_id}.png")

    file = request.files["image"]
    file.save(input_path)
    print(f"Image saved to {input_path}")         

    img = cv2.imread(input_path)

    # Clean up input file immediately after reading
    try:
        os.remove(input_path)
    except OSError:
        pass

    if img is None:
        print("❌ Error: cv2.imread returned None. Image might be corrupt or invalid format.")
        return jsonify({"error": "Invalid image format"}), 400
    
    print(f"Image shape: {img.shape}")

    print("Starting processing")
    try:
        result = daltonize(img, defect)
        del img  # free input image memory
        gc.collect()
    except Exception as e:
        del img
        gc.collect()
        print(f"❌ Error during daltonize: {e}")
        return jsonify({"error": str(e)}), 500
        
    print("Processing done")     

    cv2.imwrite(output_path, result)
    del result  # free output image memory
    gc.collect()

    if not os.path.exists(output_path):
         print("❌ Error: Output file was not written.")
         return jsonify({"error": "Processing failed to save output"}), 500

    print(f"Image written to {output_path}, Size: {os.path.getsize(output_path)} bytes")       

    # Clean up output file after sending the response
    @after_this_request
    def cleanup(response):
        try:
            os.remove(output_path)
            print(f"🧹 Cleaned up {output_path}")
        except OSError:
            pass
        return response

    return send_file(output_path, mimetype="image/png")


@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    # Check if user exists
    if db.users.find_one({'username': username}):
        return jsonify({"error": "Username already exists"}), 400

    # Create new user
    new_user = User({'username': username})
    new_user.set_password(password)
    
    db.users.insert_one(new_user.to_dict())

    return jsonify({"message": "User registered successfully"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    user_data = db.users.find_one({'username': username})

    if user_data:
        user = User(user_data)
        if user.check_password(password):
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

    # Update password in MongoDB
    user = User({'_id': ObjectId(current_user.get_id())})
    user.set_password(new_password)
    
    db.users.update_one(
        {'_id': ObjectId(current_user.get_id())},
        {'$set': {'password_hash': user.password_hash}}
    )

    return jsonify({"message": "Password updated successfully"}), 200

@app.route('/delete-account', methods=['POST'])
@login_required
def delete_account():
    try:
        db.users.delete_one({'_id': ObjectId(current_user.get_id())})
        logout_user()
        return jsonify({"message": "Account deleted successfully"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/guest-login', methods=['POST'])
def guest_login():
    guest_data = db.users.find_one({'username': 'Guest'})
    
    if not guest_data:
        # Create a Guest user with a random high-entropy password
        import secrets
        guest_user = User({'username': 'Guest'})
        guest_user.set_password(secrets.token_hex(16))
        result = db.users.insert_one(guest_user.to_dict())
        guest_data = db.users.find_one({'_id': result.inserted_id})
    
    guest_user = User(guest_data)
    login_user(guest_user)
    return jsonify({"message": "Logged in as Guest", "username": "Guest"}), 200



if __name__ == "__main__":
    port = int(os.getenv('FLASK_PORT', 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
