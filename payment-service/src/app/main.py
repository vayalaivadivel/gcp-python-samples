import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, List

from flask import Flask, jsonify, request
from google.cloud import pubsub_v1

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

PROJECT_ID = os.getenv("PROJECT_ID", "").strip()
TOPIC_NAME = os.getenv("TOPIC_NAME", "").strip()
SERVICE_NAME = os.getenv("SERVICE_NAME", "payment-service").strip()
ENV = os.getenv("ENV", "dev").strip()

publisher = pubsub_v1.PublisherClient()
TOPIC_PATH = publisher.topic_path(PROJECT_ID, TOPIC_NAME) if PROJECT_ID and TOPIC_NAME else None


def validate_payload(payload: Dict[str, Any]) -> List[str]:
    errors: List[str] = []

    required_fields = [
        "payment_id",
        "customer_id",
        "amount",
        "currency",
        "status",
        "event_time",
    ]

    for field in required_fields:
        if field not in payload:
            errors.append(f"Missing required field: {field}")

    if "payment_id" in payload and not str(payload["payment_id"]).strip():
        errors.append("payment_id must not be empty")

    if "customer_id" in payload and not str(payload["customer_id"]).strip():
        errors.append("customer_id must not be empty")

    if "currency" in payload and not str(payload["currency"]).strip():
        errors.append("currency must not be empty")

    if "status" in payload and not str(payload["status"]).strip():
        errors.append("status must not be empty")

    if "amount" in payload:
        try:
            amount = float(payload["amount"])
            if amount < 0:
                errors.append("amount must be greater than or equal to 0")
        except (TypeError, ValueError):
            errors.append("amount must be a valid number")

    if "event_time" in payload:
        event_time = str(payload["event_time"]).strip()
        try:
            # Accepts values like 2026-04-05T10:15:00Z
            datetime.fromisoformat(event_time.replace("Z", "+00:00"))
        except ValueError:
            errors.append("event_time must be a valid ISO-8601 timestamp")

    return errors


@app.route("/health", methods=["GET"])
def health() -> Any:
    if not PROJECT_ID or not TOPIC_NAME or not TOPIC_PATH:
        return jsonify(
            {
                "status": "unhealthy",
                "reason": "Missing PROJECT_ID or TOPIC_NAME environment variables",
            }
        ), 500

    return jsonify(
        {
            "status": "ok",
            "service": SERVICE_NAME,
            "environment": ENV,
            "topic": TOPIC_NAME,
        }
    ), 200


@app.route("/payments", methods=["POST"])
def publish_payment() -> Any:
    if not PROJECT_ID or not TOPIC_NAME or not TOPIC_PATH:
        logger.error("Missing PROJECT_ID or TOPIC_NAME environment variables")
        return jsonify(
            {
                "error": "Server configuration error",
                "details": "PROJECT_ID and TOPIC_NAME must be configured",
            }
        ), 500

    try:
        payload = request.get_json(silent=True)

        if not payload:
            return jsonify({"error": "Request body must be valid JSON"}), 400

        if not isinstance(payload, dict):
            return jsonify({"error": "JSON body must be an object"}), 400

        validation_errors = validate_payload(payload)
        if validation_errors:
            return jsonify(
                {
                    "error": "Validation failed",
                    "details": validation_errors,
                }
            ), 400

        enriched_payload = {
            **payload,
            "received_at": datetime.now(timezone.utc).isoformat(),
            "source": SERVICE_NAME,
            "environment": ENV,
        }

        message_data = json.dumps(enriched_payload).encode("utf-8")

        publish_future = publisher.publish(
            TOPIC_PATH,
            message_data,
            event_type="payment.created",
            source=SERVICE_NAME,
            environment=ENV,
            payment_id=str(payload["payment_id"]),
            customer_id=str(payload["customer_id"]),
            status=str(payload["status"]),
        )

        message_id = publish_future.result()

        logger.info(
            "Published payment event successfully | payment_id=%s message_id=%s",
            payload["payment_id"],
            message_id,
        )

        return jsonify(
            {
                "message": "Payment event published successfully",
                "message_id": message_id,
                "topic": TOPIC_NAME,
            }
        ), 202

    except Exception as exc:
        logger.exception("Failed to publish payment event")
        return jsonify(
            {
                "error": "Internal server error",
                "details": str(exc),
            }
        ), 500


@app.route("/", methods=["GET"])
def root() -> Any:
    return jsonify(
        {
            "service": SERVICE_NAME,
            "environment": ENV,
            "endpoints": ["/health", "/payments"],
        }
    ), 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)