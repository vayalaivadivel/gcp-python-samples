import os
import csv
import logging
import tempfile

import mysql.connector
from google.cloud import storage

logging.basicConfig(level=logging.INFO)

CREATE_EMP_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS emp (
    emp_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_name VARCHAR(100) NOT NULL,
    dept VARCHAR(100),
    salary DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
"""

CREATE_TOTAL_SALARY_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS total_salary (
    id INT PRIMARY KEY AUTO_INCREMENT,
    file_name VARCHAR(255) NOT NULL,
    total_salary DECIMAL(12,2) NOT NULL,
    total_employees INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
"""

INSERT_EMP_SQL = """
INSERT INTO emp (emp_id, emp_name, dept, salary)
VALUES (%s, %s, %s, %s)
"""

INSERT_EMP_NO_ID_SQL = """
INSERT INTO emp (emp_name, dept, salary)
VALUES (%s, %s, %s)
"""

INSERT_TOTAL_SALARY_SQL = """
INSERT INTO total_salary (file_name, total_salary, total_employees)
VALUES (%s, %s, %s)
"""


def get_db_connection():
    return mysql.connector.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        database=os.environ["DB_NAME"],
    )


def create_emp_table_if_not_exists(cursor):
    cursor.execute(CREATE_EMP_TABLE_SQL)


def create_total_salary_table_if_not_exists(cursor):
    cursor.execute(CREATE_TOTAL_SALARY_TABLE_SQL)


def download_file_from_gcs(bucket_name, file_name, local_path):
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    blob.download_to_filename(local_path)


def parse_decimal(value):
    if value is None or str(value).strip() == "":
        return None
    return float(value)


def parse_int(value):
    if value is None or str(value).strip() == "":
        return None
    return int(value)


def process_csv_and_insert(cursor, csv_file_path):
    inserted_count = 0
    total_salary = 0.0

    with open(csv_file_path, mode="r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)

        required_columns = {"emp_name", "dept", "salary"}
        missing = required_columns - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing required CSV columns: {', '.join(sorted(missing))}")

        for row in reader:
            emp_id = parse_int(row.get("emp_id"))
            emp_name = (row.get("emp_name") or "").strip()
            dept = (row.get("dept") or "").strip() or None
            salary = parse_decimal(row.get("salary"))

            if not emp_name:
                logging.warning("Skipping row because emp_name is empty: %s", row)
                continue

            if emp_id is not None:
                cursor.execute(INSERT_EMP_SQL, (emp_id, emp_name, dept, salary))
            else:
                cursor.execute(INSERT_EMP_NO_ID_SQL, (emp_name, dept, salary))

            inserted_count += 1
            total_salary += salary if salary is not None else 0.0

    return inserted_count, total_salary


def insert_total_salary_summary(cursor, file_name, total_salary, total_employees):
    cursor.execute(
        INSERT_TOTAL_SALARY_SQL,
        (file_name, total_salary, total_employees)
    )


def etl_handler(event, context):
    bucket_name = event.get("bucket")
    file_name = event.get("name")

    if not bucket_name or not file_name:
        logging.error("Missing cloud-storage bucket or file name in event: %s", event)
        return

    logging.info("Triggered for bucket=%s, file=%s", bucket_name, file_name)

    if not file_name.lower().endswith(".csv"):
        logging.info("Skipping non-CSV file: %s", file_name)
        return

    temp_dir = tempfile.gettempdir()
    local_file_path = os.path.join(temp_dir, os.path.basename(file_name))

    conn = None
    cursor = None

    try:
        download_file_from_gcs(bucket_name, file_name, local_file_path)

        conn = get_db_connection()
        cursor = conn.cursor()

        create_emp_table_if_not_exists(cursor)
        create_total_salary_table_if_not_exists(cursor)

        inserted_count, total_salary = process_csv_and_insert(cursor, local_file_path)
        insert_total_salary_summary(cursor, file_name, total_salary, inserted_count)

        conn.commit()

        logging.info(
            "Inserted %s rows into emp table from file %s; total salary = %s",
            inserted_count,
            file_name,
            total_salary,
        )

    except Exception as e:
        if conn:
            conn.rollback()
        logging.exception("ETL failed for file %s: %s", file_name, str(e))
        raise

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()
        if os.path.exists(local_file_path):
            os.remove(local_file_path)