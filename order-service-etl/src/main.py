import base64
import json


def process_order_event(event, context):
    pubsub_message = base64.b64decode(event["data"]).decode("utf-8")
    order_event = json.loads(pubsub_message)

    print(f"Received event: {order_event}")

    event_type = order_event.get("event_type")
    if event_type == "ORDER_CREATED":
        order_data = order_event["data"]
        print(f"Processing order: {order_data['order_id']}")