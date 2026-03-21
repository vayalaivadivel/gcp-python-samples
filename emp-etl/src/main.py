import os
import csv
import mysql.connector
from google.cloud import storage
from datetime import datetime

def etl_job(request):
    conn = mysql.connector.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ["DB_NAME"]
    )

    cursor = conn.cursor()
    cursor.execute("SELECT * FROM emp")
    rows = cursor.fetchall()
    columns = [col[0] for col in cursor.description]

    file_name = f"/tmp/emp_{datetime.now().strftime('%Y%m%d%H%M%S')}.csv"

    with open(file_name, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        writer.writerows(rows)

    client = storage.Client()
    bucket = client.bucket(os.environ["BUCKET_NAME"])
    blob = bucket.blob(f"emp/{file_name.split('/')[-1]}")
    blob.upload_from_filename(file_name)

    return "ETL Completed"