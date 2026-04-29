import os
import json
import boto3
import redis
import psycopg2
from pymongo import MongoClient
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv
import requests

load_dotenv()

app = FastAPI()

# --- Config from env or sensible defaults for local KinD ---
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres-rw.postgres.svc.cluster.local")
POSTGRES_DB = os.getenv("POSTGRES_DB", "app")
POSTGRES_USER = os.getenv("POSTGRES_USER", "app")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "app")

MONGO_URI = os.getenv("MONGO_URI", "mongodb://app:app@mongodb.mongodb.svc.cluster.local:27017/app?authSource=app")

REDIS_HOST = os.getenv("REDIS_HOST", "valkey-primary.valkey.svc.cluster.local")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "valkey")

S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://s3.k8s.local")
S3_ACCESS_KEY = os.getenv("S3_ACCESS_KEY", "admin")
S3_SECRET_KEY = os.getenv("S3_SECRET_KEY", "admin")
S3_BUCKET = os.getenv("S3_BUCKET", "demo-bucket")

OPENBAO_ADDR = os.getenv("OPENBAO_ADDR", "http://openbao.openbao.svc.cluster.local:8200")
OPENBAO_ROLE = os.getenv("OPENBAO_ROLE", "demo-app")

# --- DB Connections ---
def get_pg_conn():
    return psycopg2.connect(
        host=POSTGRES_HOST, dbname=POSTGRES_DB, user=POSTGRES_USER, password=POSTGRES_PASSWORD
    )

mongo_client = MongoClient(MONGO_URI)
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASSWORD, decode_responses=True)
s3 = boto3.client(
    "s3",
    endpoint_url=S3_ENDPOINT,
    aws_access_key_id=S3_ACCESS_KEY,
    aws_secret_access_key=S3_SECRET_KEY,
)

# --- OpenBao secret fetch ---
def get_openbao_secret():
    # Use the pod's service account JWT
    try:
        with open("/var/run/secrets/kubernetes.io/serviceaccount/token") as f:
            jwt = f.read().strip()
    except Exception:
        return None
    login = requests.post(
        f"{OPENBAO_ADDR}/v1/auth/kubernetes/login",
        json={"role": OPENBAO_ROLE, "jwt": jwt},
        timeout=3,
    )
    if not login.ok:
        return None
    token = login.json()["auth"]["client_token"]
    secret = requests.get(
        f"{OPENBAO_ADDR}/v1/secret/data/demo-app",
        headers={"X-Vault-Token": token},
        timeout=3,
    )
    if not secret.ok:
        return None
    return secret.json()["data"]["data"]

@app.get("/")
def root():
    return {"status": "ok"}

@app.get("/demo")
def demo():
    # 1. Read a secret from OpenBao
    secret = get_openbao_secret() or {}

    # 2. Write/read a value in Valkey
    redis_client.set("demo:last", "hello from fullstack app")
    redis_val = redis_client.get("demo:last")

    # 3. Insert a row in PostgreSQL
    with get_pg_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS fullstack_demo_events (id SERIAL PRIMARY KEY, message TEXT, created_at TIMESTAMPTZ DEFAULT NOW())"
            )
            cur.execute(
                "INSERT INTO fullstack_demo_events (message) VALUES (%s) RETURNING id, created_at",
                ("hello from fullstack app",),
            )
            row = cur.fetchone()
            conn.commit()

    # 4. Insert a document in MongoDB
    doc = {"message": "hello from fullstack app"}
    mongo_client[POSTGRES_DB].demo_events.insert_one(doc)

    # 5. Upload a file to SeaweedFS S3
    s3.put_object(Bucket=S3_BUCKET, Key="demo.txt", Body=b"hello from fullstack app")

    return {
        "secret": secret,
        "redis": redis_val,
        "postgres": {"id": row[0], "created_at": str(row[1])},
        "mongodb": "ok",
        "s3": "uploaded demo.txt",
    }

@app.get("/demo/download")
def demo_download():
    # Download the file from S3
    obj = s3.get_object(Bucket=S3_BUCKET, Key="demo.txt")
    return {"content": obj["Body"].read().decode()}
