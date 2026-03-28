import os
import json
import base64
import logging
import mysql.connector

logging.basicConfig(level=logging.INFO)

def get_db_connection():
    return mysql.connector.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ["DB_NAME"]
    )

def process_order_event(event, context):
    logging.info("Received Pub/Sub event")

    try:
        if "data" not in event:
            logging.error("No data found in Pub/Sub message")
            return

        payload = base64.b64decode(event["data"]).decode("utf-8")
        order_data = json.loads(payload)

        logging.info(f"Decoded order data: {order_data}")

        order_id = order_data.get("order_id")
        customer_name = order_data.get("customer_name")
        product_name = order_data.get("product_name")
        quantity = order_data.get("quantity")
        amount = order_data.get("amount")
        status = order_data.get("status", "NEW")

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                order_id VARCHAR(100) NOT NULL,
                customer_name VARCHAR(255),
                product_name VARCHAR(255),
                quantity INT,
                amount DECIMAL(10,2),
                status VARCHAR(50),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        cursor.execute("""
            INSERT INTO orders (
                order_id, customer_name, product_name, quantity, amount, status
            ) VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            order_id, customer_name, product_name, quantity, amount, status
        ))

        conn.commit()
        cursor.close()
        conn.close()

        logging.info(f"Order inserted successfully: {order_id}")

    except Exception as e:
        logging.error(f"Failed to process Pub/Sub message: {str(e)}", exc_info=True)
        raise