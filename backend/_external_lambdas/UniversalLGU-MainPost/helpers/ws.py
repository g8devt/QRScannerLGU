import json
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()


def get_management_client(endpoint_url):
    return boto3.client('apigatewaymanagementapi', endpoint_url=endpoint_url)


def send_to_connection(client, cur, connection_id, payload):
    try:
        client.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps(payload, default=str).encode('utf-8'),
        )
        return True
    except ClientError as e:
        status = e.response.get('ResponseMetadata', {}).get('HTTPStatusCode')
        if status == 410:
            cur.execute(
                "DELETE FROM app_admin_kyc_connections WHERE connection_id=%s",
                (connection_id,),
            )
            return False
        logger.error(f"post_to_connection failed for {connection_id}: {e}")
        return False


def broadcast(cur, endpoint_url, role, payload, submission_id=None):
    client = get_management_client(endpoint_url)
    if role == 'applicant' and submission_id is not None:
        cur.execute(
            "SELECT connection_id FROM app_admin_kyc_connections "
            "WHERE role='applicant' AND submission_id=%s",
            (submission_id,),
        )
    else:
        cur.execute(
            "SELECT connection_id FROM app_admin_kyc_connections WHERE role=%s",
            (role,),
        )
    for row in cur.fetchall():
        send_to_connection(client, cur, row['connection_id'], payload)
