import os
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(
    0,
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")),
)

import app as application


class FlaskApplicationTests(unittest.TestCase):

    def setUp(self):
        application.app.config["TESTING"] = True
        self.client = application.app.test_client()

    def test_home_endpoint(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)

        data = response.get_json()
        self.assertEqual(data["status"], "running")
        self.assertEqual(
            data["application"],
            "Production Kubernetes Platform",
        )
        self.assertIn("hostname", data)
        self.assertIn("timestamp", data)

    def test_health_endpoint(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.get_json(),
            {"status": "healthy"},
        )

    def test_readiness_endpoint(self):
        response = self.client.get("/ready")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.get_json(),
            {"status": "ready"},
        )

    def test_info_endpoint(self):
        response = self.client.get("/info")

        self.assertEqual(response.status_code, 200)

        data = response.get_json()
        self.assertEqual(
            data["application"],
            "Production Kubernetes Platform",
        )
        self.assertEqual(data["environment"], "development")
        self.assertIn("hostname", data)

    @patch.object(application, "get_database_connection")
    def test_database_health_when_connected(self, mock_connection):
        connection = MagicMock()
        cursor = MagicMock()

        mock_connection.return_value.__enter__.return_value = connection
        connection.cursor.return_value.__enter__.return_value = cursor
        cursor.fetchone.return_value = (
            "platformdb",
            "platformuser",
            "PostgreSQL 16.15 on test environment",
        )

        response = self.client.get("/db-health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.get_json()["status"],
            "connected",
        )
        self.assertEqual(
            response.get_json()["database"],
            "platformdb",
        )
        self.assertEqual(
            response.get_json()["user"],
            "platformuser",
        )

    @patch.object(
        application,
        "get_database_connection",
        side_effect=application.psycopg.OperationalError(
            "Simulated database connection failure"
        ),
    )
    def test_database_health_when_unavailable(self, mock_connection):
        response = self.client.get("/db-health")

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.get_json()["status"],
            "unavailable",
        )
        self.assertEqual(
            response.get_json()["message"],
            "Database connectivity check failed",
        )


if __name__ == "__main__":
    unittest.main()
