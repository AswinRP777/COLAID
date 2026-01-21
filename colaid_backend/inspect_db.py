from app import app, db, User

def inspect():
    with app.app_context():
        users = User.query.all()
        print(f"Total Users: {len(users)}")
        print("-" * 30)
        print(f"{'ID':<5} | {'Username'}")
        print("-" * 30)
        for user in users:
            print(f"{user.id:<5} | {user.username}")
        print("-" * 30)

if __name__ == "__main__":
    inspect()
