import os
from datetime import datetime, timezone

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "db")
DB_NAME = os.environ.get("DB_NAME", "postgres")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "postgres")
DB_PORT = os.environ.get("DB_PORT", "5432")


def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            port=DB_PORT,
        )
        return conn
    except psycopg2.OperationalError as e:
        print(f"Error: Could not connect to database. {e}")
        return None


@app.route("/")
def index():
    return jsonify({"message": "GoalTracker backend is running."})


@app.route("/sync", methods=["GET"])
def sync_goals():
    last_sync_str = request.args.get("last_sync_timestamp")
    if last_sync_str:
        try:
            if last_sync_str.upper().endswith("Z"):
                last_sync_str = last_sync_str[:-1] + "+00:00"
            last_sync_timestamp = datetime.fromisoformat(last_sync_str)
        except ValueError:
            return jsonify(
                {"error": "Invalid timestamp format. Please use ISO 8601."}
            ), 400
    else:
        last_sync_timestamp = datetime(1970, 1, 1, tzinfo=timezone.utc)

    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 500

    cursor = conn.cursor()

    try:
        query = "SELECT id, name, target_value, current_value, updated_at FROM goals WHERE updated_at > %s ORDER BY updated_at;"
        cursor.execute(query, (last_sync_timestamp,))

        goals = cursor.fetchall()

        column_names = [desc[0] for desc in cursor.description]

        result_list = []
        for goal in goals:
            goal_dict = dict(zip(column_names, goal))
            goal_dict["id"] = str(goal_dict["id"])
            goal_dict["updated_at"] = goal_dict["updated_at"].isoformat()
            result_list.append(goal_dict)

        return jsonify(
            {
                "goals": result_list,
                "server_timestamp": datetime.now(timezone.utc).isoformat(),
            }
        )

    except Exception as e:
        print(f"An error occurred during sync: {e}")
        return jsonify({"error": "An internal error occurred"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
