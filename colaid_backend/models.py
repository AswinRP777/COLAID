from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from bson import ObjectId

class User(UserMixin):
    def __init__(self, user_data):
        self._id = user_data.get('_id')
        self.username = user_data.get('username')
        self.password_hash = user_data.get('password_hash')
    
    def get_id(self):
        return str(self._id)
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self):
        return {
            'username': self.username,
            'password_hash': self.password_hash
        }
