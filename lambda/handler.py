"""Função de exemplo: prova que a Lambda enxerga o S3 e o RDS de dentro da VPC."""
import json
import os
import socket

import boto3


def lambda_handler(event, context):
    s3 = boto3.client("s3")
    objetos = s3.list_objects_v2(Bucket=os.environ["BUCKET"], MaxKeys=5)

    host, porta = os.environ["DB_HOST"], int(os.environ["DB_PORT"])
    try:
        with socket.create_connection((host, porta), timeout=3):
            rds = "alcancavel"
    except OSError as erro:
        rds = f"inalcancavel: {erro}"

    return {
        "statusCode": 200,
        "body": json.dumps({
            "s3_bucket": os.environ["BUCKET"],
            "s3_objetos": objetos.get("KeyCount", 0),
            "rds": f"{host}:{porta} {rds}",
        }),
    }
