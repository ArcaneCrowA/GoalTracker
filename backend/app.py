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


def _init_db():
    """Initializes the database schema if it doesn't exist."""
    conn = get_db_connection()
    if conn is None:
        print("Database connection failed during initialization.")
        return

    cursor = conn.cursor()
    try:
        # Create goals table
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS goals (
                id UUID PRIMARY KEY,
                name TEXT NOT NULL,
                target_value INTEGER NOT NULL,
                current_value INTEGER NOT NULL,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            """
        )
        # Create trigger function
        cursor.execute(
            """
            CREATE OR REPLACE FUNCTION set_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = NOW();
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
            """
        )
        # Attach the trigger to the table
        cursor.execute(
            """
            DO $$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_goal_updated_at') THEN
                    CREATE TRIGGER update_goal_updated_at
                    BEFORE UPDATE ON goals
                    FOR EACH ROW
                    EXECUTE PROCEDURE set_updated_at();
                END IF;
            END $$;
            """
        )
        conn.commit()
        print(
            "Database schema initialized successfully (goals table and trigger)."
        )
    except Exception as e:
        conn.rollback()
        print(f"An error occurred during database initialization: {e}")
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


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


@app.route("/goals", methods=["POST"])
def create_goal():
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 500

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request must contain JSON data"}), 400

    required_fields = [
        "id",
        "name",
        "target_value",
        "current_value",
        "updated_at",
    ]
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400

    cursor = conn.cursor()
    try:
        query = "INSERT INTO goals (id, name, target_value, current_value, updated_at) VALUES (%s, %s, %s, %s, %s) RETURNING id, name, target_value, current_value, updated_at;"
        cursor.execute(
            query,
            (
                data["id"],
                data["name"],
                data["target_value"],
                data["current_value"],
                datetime.fromisoformat(data["updated_at"]),
            ),
        )
        conn.commit()
        new_goal = cursor.fetchone()
        column_names = [desc[0] for desc in cursor.description]
        goal_dict = dict(zip(column_names, new_goal))
        goal_dict["id"] = str(goal_dict["id"])
        goal_dict["updated_at"] = goal_dict["updated_at"].isoformat()
        return jsonify(goal_dict), 201
    except psycopg2.IntegrityError as e:
        conn.rollback()
        return jsonify({"error": f"Integrity error: {e}"}), 409
    except Exception as e:
        conn.rollback()
        print(f"An error occurred during goal creation: {e}")
        return jsonify({"error": "An internal error occurred"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


@app.route("/goals/<uuid:goal_id>", methods=["PUT"])
def update_goal(goal_id):
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 500

    data = request.get_json()
    if not data:
        return jsonify({"error": "Request must contain JSON data"}), 400

    # Only allow specific fields to be updated, and rely on the trigger for updated_at
    allowed_fields = ["name", "target_value", "current_value", "updated_at"]
    update_fields = []
    update_values = []

    for field in allowed_fields:
        if field in data:
            update_fields.append(f"{field} = %s")
            if field == "updated_at":
                update_values.append(datetime.fromisoformat(data[field]))
            else:
                update_values.append(data[field])

    if not update_fields:
        return jsonify({"error": "No fields provided for update"}), 400

    cursor = conn.cursor()
    try:
        query = f"UPDATE goals SET {', '.join(update_fields)} WHERE id = %s RETURNING id, name, target_value, current_value, updated_at;"
        update_values.append(str(goal_id))
        cursor.execute(query, tuple(update_values))
        conn.commit()

        updated_goal = cursor.fetchone()
        if not updated_goal:
            return jsonify({"error": "Goal not found"}), 404

        column_names = [desc[0] for desc in cursor.description]
        goal_dict = dict(zip(column_names, updated_goal))
        goal_dict["id"] = str(goal_dict["id"])
        goal_dict["updated_at"] = goal_dict["updated_at"].isoformat()
        return jsonify(goal_dict)
    except Exception as e:
        conn.rollback()
        print(f"An error occurred during goal update: {e}")
        return jsonify({"error": "An internal error occurred"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


@app.route("/goals/<uuid:goal_id>", methods=["DELETE"])
def delete_goal(goal_id):
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 500

    cursor = conn.cursor()
    try:
        query = "DELETE FROM goals WHERE id = %s;"
        cursor.execute(query, (str(goal_id),))
        conn.commit()

        if cursor.rowcount == 0:
            return jsonify({"error": "Goal not found"}), 404

        return jsonify({"message": f"Goal {goal_id} deleted successfully"}), 204
    except Exception as e:
        conn.rollback()
        print(f"An error occurred during goal deletion: {e}")
        return jsonify({"error": "An internal error occurred"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


if __name__ == "__main__":
    _init_db()  # Initialize database schema on startup
    app.run(host="0.0.0.0", port=5001, debug=True)
