import os
import csv
import logging
from datetime import datetime
import mysql.connector
from google.cloud import storage

logging.basicConfig(level=logging.INFO)

def main():
    try:
        # ENV variables
        db_host = os.environ.get("DB_HOST")
        db_user = os.environ.get("DB_USER")
        db_pass = os.environ.get("DB_PASS")
        db_name = os.environ.get("DB_NAME")
        bucket_name = os.environ.get("BUCKET_NAME")

        logging.info("Connecting to MySQL...")

        conn = mysql.connector.connect(
            host=db_host,
            user=db_user,
            password=db_pass,
            database=db_name
        )

        cursor = conn.cursor()
        cursor.execute("SELECT * FROM emp")

        rows = cursor.fetchall()
        columns = [col[0] for col in cursor.description]

        file_name = f"/tmp/emp_{datetime.now().strftime('%Y%m%d%H%M%S')}.csv"

        logging.info(f"Writing file {file_name}")

        with open(file_name, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(columns)
            writer.writerows(rows)

        logging.info("Uploading to GCS...")

        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(f"emp/{os.path.basename(file_name)}")
        blob.upload_from_filename(file_name)

        logging.info("Upload complete")

    except Exception as e:
        logging.error(f"Error: {str(e)}")
        raise

if __name__ == "__main__":
    main()