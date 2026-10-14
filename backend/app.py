from datetime import datetime, timezone
import os
import socket

import psycopg
from flask import Flask, jsonify

app = Flask(__name__)

APP_NAME = os.getenv(
    "APP_NAME",
    "Production Kubernetes Platform",
)


def get_database_connection():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        dbname=os.getenv("DB_NAME", "platformdb"),
        user=os.getenv("DB_USER", "platformuser"),
        password=os.getenv("DB_PASSWORD", ""),
        connect_timeout=3,
    )


@app.route("/")
def home():
    return jsonify({
        "application": APP_NAME,
        "status": "running",
        "hostname": socket.gethostname(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200


@app.route("/info")
def info():
    return jsonify({
        "application": APP_NAME,
        "environment": os.getenv("APP_ENV", "development"),
        "hostname": socket.gethostname(),
    })


@app.route("/db-health")
def db_health():
    try:
        with get_database_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT current_database(), current_user, version()"
                )
                database, user, version = cursor.fetchone()

                return jsonify({
                    "status": "connected",
                    "database": database,
                    "user": user,
                    "postgres_version": version.split(",")[0],
                }), 200

    except psycopg.Error:
        app.logger.exception(
            "PostgreSQL connectivity check failed"
        )
        return jsonify({
            "status": "unavailable",
            "message": "Database connectivity check failed",
        }), 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
