from flask import Flask, request, send_file, jsonify
import cv2
import os
from daltonize import daltonize

app = Flask(__name__)
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
    print("Image saved")         

    img = cv2.imread(input_path)
    if img is None:
        return jsonify({"error": "Invalid image"}), 400

    print("Starting processing")
    result = daltonize(img, defect)
    print("Processing done")     

    cv2.imwrite(output_path, result)
    print("Image written")       

    return send_file(output_path, mimetype="image/png")



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
