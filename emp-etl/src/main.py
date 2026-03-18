import os
import pandas as pd
import pymysql
from google.cloud import storage
import io

def etl_handler(event, context):

    try:
        bucket_name = event['bucket']
        file_name = event['name']

        print(f"Processing file: gs://{bucket_name}/{file_name}")

        storage_client = storage.Client()
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(file_name)

        data = blob.download_as_bytes()

        df = pd.read_csv(io.BytesIO(data))
        print("CSV loaded successfully")

        connection = pymysql.connect(
            host=os.environ['MYSQL_HOST'],
            user=os.environ['MYSQL_USER'],
            password=os.environ['MYSQL_PASSWORD'],
            database=os.environ['MYSQL_DB'],
            port=3306
        )

        print("Connected to MySQL")

        cursor = connection.cursor()

        rows = []
        for _, row in df.iterrows():
            rows.append((
                row.get('name'),
                row.get('salary'),
                row.get('department')
            ))

        sql = "INSERT INTO emp (name, salary, department) VALUES (%s,%s,%s)"

        cursor.executemany(sql, rows)

        connection.commit()
        cursor.close()
        connection.close()

        print("Data inserted successfully")

    except Exception as e:
        print("ERROR:", str(e))