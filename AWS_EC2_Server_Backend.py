# Backend initial demo
from flask import Flask, request, jsonify
import json
import os
from datetime import datetime

app = Flask(__name__)

DATA_FILE = "robot_data.json"

# --- Load & Save Helpers ---

def load_robot_data():
    """Load existing robot data from JSON file, or start fresh."""
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            print("[WARN] robot_data.json corrupted — resetting file.")
            return {}
    return {}

def save_robot_data(data):
    """Save robot data back to JSON file with indentation."""
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=4)


# Initialize memory copy
robot_data = load_robot_data()


# --- Routes ---

@app.route('/send_command', methods=['POST'])
def send_command():
    data = request.json or {}
    command = data.get('command', '').strip()

    if not command:
        return jsonify({"error": "Missing command"}), 400

    print(f"[COMMAND] Received: {command}")

    # Log command and timestamp
    robot_data["last_command"] = {
        "command": command,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    save_robot_data(robot_data)

    # TODO: Forward to robot via Wi-Fi later
    return jsonify({"status": "ok", "command": command}), 200

@app.route('/robot_update', methods=['POST'])
def robot_update():
    data = request.json or {}
    robot_id = data.get('robot_id', 'unknown')
    battery = data.get('battery', 'N/A')
    status = data.get('status', 'unknown')

    robot_data[robot_id] = {
        "battery": battery,
        "status": status,
        "last_update": datetime.utcnow().isoformat() + "Z"
    }
    save_robot_data(robot_data)

    print(f"[UPDATE] {robot_id} → Battery={battery}, Status={status}")
    return jsonify({"status": "update saved"}), 200


@app.route('/robot_status/<robot_id>', methods=['GET'])
def get_robot_status(robot_id):
    info = robot_data.get(robot_id)
    if not info:
        return jsonify({"error": "Robot not found"}), 404
    return jsonify(info)

@app.route('/')
def home():
    return "Robot Backend is running on AWS EC2"


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)