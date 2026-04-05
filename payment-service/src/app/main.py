import os
import json
import logging
from datetime import datetime, timezone

from flask import Flask, request, jsonify
from google.cloud import pubsub_v1

logging.basicConfig(level=logging.INFO)

app = Flask(__name__)

PROJECT_ID = os.environ["PROJECT_ID"]
TOPIC_NAME = os.environ["TOPIC_NAME"]

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_NAME)


def normalize_payment(payload: dict) -> dict:
    return {
        "payment_id": payload.get("payment_id"),
        "order_id": payload.get("order_id"),
        "customer_id": payload.get("customer_id"),
        "amount": payload.get("amount"),
        "currency": payload.get("currency", "INR"),
        "status": payload.get("status", "NEW"),
        "payment_method": payload.get("payment_method"),
        "provider": payload.get("provider", "external-api"),
        "event_time": payload.get("event_time"),
        "ingested_at": datetime.now(timezone.utc).isoformat()
    }


@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/payment", methods=["POST"])
def publish_payment():
    payload = request.get_json(silent=True) or {}
    payment_event = normalize_payment(payload)

    if not payment_event["payment_id"]:
        return jsonify({"error": "payment_id is required"}), 400

    data = json.dumps(payment_event).encode("utf-8")
    future = publisher.publish(topic_path, data)

    message_id = future.result()
    logging.info("Published payment event: %s", message_id)

    return jsonify({
        "status": "published",
        "message_id": message_id,
        "payment_id": payment_event["payment_id"]
    }), 200