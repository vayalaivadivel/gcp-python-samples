# 🚀 GCP Serverless ETL Platform (Batch + Event-Driven)

![Terraform](https://img.shields.io/badge/Terraform-IaC-blueviolet)
![GCP](https://img.shields.io/badge/GCP-Cloud-blue)
![Python](https://img.shields.io/badge/Python-3.11-yellow)
![CI/CD](https://img.shields.io/badge/GitHub%20Actions-CI/CD-black)
![Cloud
Functions](https://img.shields.io/badge/Cloud%20Functions-Serverless-orange)

------------------------------------------------------------------------

## 📌 Overview

This project implements a **production-ready serverless ETL platform on
GCP** supporting:

### 🔹 Batch Pipeline → emp-etl

-   Trigger: Cloud Storage
-   Input: CSV files
-   Output: Cloud SQL (MySQL)

### 🔹 Event Pipeline → order-service-etl

-   Trigger: Pub/Sub
-   Input: JSON messages
-   Output: Cloud SQL (MySQL)

------------------------------------------------------------------------

## 🏗️ Architecture

### Batch ETL

CSV → Cloud Storage → Cloud Function → MySQL

### Event ETL

Producer → Pub/Sub → Cloud Function → MySQL

------------------------------------------------------------------------

## 📂 Project Structure

. ├── emp-etl/ │ ├── src/ │ │ ├── main.py │ │ └── requirements.txt │ └──
test/ │ └── emp.csv │ ├── order-service-etl/ │ ├── src/ │ │ ├── main.py
│ │ └── requirements.txt │ └── test/ │ └── publish_order.py │ ├── infra/
│ ├── main.tf │ ├── variables.tf │ ├── output.tf │ ├── provider.tf │ └──
env/ │ ├── dev.tfvars │ └── prod.tfvars │ └── README.md

------------------------------------------------------------------------

## ⚙️ Tech Stack

-   Cloud Functions
-   Cloud Storage
-   Pub/Sub
-   Cloud SQL (MySQL)
-   Secret Manager
-   Terraform
-   GitHub Actions
-   Python

------------------------------------------------------------------------

## 🚀 Deployment

cd infra terraform init terraform apply -var="env=dev"
-var-file="env/dev.tfvars"

------------------------------------------------------------------------

## 📤 Testing

### Batch

gcloud storage cp emp-etl/test/emp.csv gs://`<bucket>`{=html}

### Event

gcloud pubsub topics publish order-events-dev\
--message='{"order_id":"ORD1001","customer_name":"Vadivel"}'

------------------------------------------------------------------------

## 📊 Output

Tables: - emp (batch) - orders (event)

------------------------------------------------------------------------

## 🎯 Key Features

-   Serverless architecture
-   Batch + real-time pipelines
-   Secure secret handling
-   CI/CD enabled
-   Scalable design

------------------------------------------------------------------------

## 👨‍💻 Author

Vadivel P M