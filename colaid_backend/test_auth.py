import requests

BASE_URL = "http://127.0.0.1:5000"

def test_auth():
    print("Testing Registration...")
    reg_data = {"username": "testuser", "password": "password123"}
    try:
        r = requests.post(f"{BASE_URL}/register", json=reg_data)
        print(f"Register: {r.status_code} - {r.text}")
    except Exception as e:
        print(f"Register failed: {e}")

    print("\nTesting Login...")
    login_data = {"username": "testuser", "password": "password123"}
    session = requests.Session()
    try:
        r = session.post(f"{BASE_URL}/login", json=login_data)
        print(f"Login: {r.status_code} - {r.text}")
    except Exception as e:
        print(f"Login failed: {e}")

    print("\nTesting Protected Route (Logout)...")
    try:
        r = session.post(f"{BASE_URL}/logout")
        print(f"Logout: {r.status_code} - {r.text}")
    except Exception as e:
        print(f"Logout failed: {e}")

    print("\nTesting Invalid Login...")
    invalid_data = {"username": "testuser", "password": "wrongpassword"}
    try:
        r = requests.post(f"{BASE_URL}/login", json=invalid_data)
        print(f"Invalid Login: {r.status_code} - {r.text}")
    except Exception as e:
        print(f"Invalid Login failed: {e}")

if __name__ == "__main__":
    test_auth()
