import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2_client = boto3.client("ec2")
sns_client = boto3.client("sns")

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")

def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    if 'body' in event:
        payload = json.loads(event['body'])
    else:
        payload = event
        
    logger.info("Parsed payload: %s", json.dumps(payload))

    results = payload.get('results')
    results = json.loads(results)

    logger.info("Parsed results: %s", json.dumps(results))

    instances_to_restart = []
    for result in results:
        count = int(result.get('Count'))
        if count > 5:
            instance_id = result.get('instance_id')
            instances_to_restart.append(instance_id)

    # Reboot EC2 instance
    messages = []
    try:
        for instance in instances_to_restart:
            ec2_client.reboot_instances(InstanceIds=[instance])
            message = f"EC2 instance {instance} reboot triggered due to Sumo Logic alert."
            logger.info(message)
    except Exception as e:
        logger.error("Failed to reboot instance: %s", str(e))
        raise

    # Send SNS notification
    if SNS_TOPIC_ARN:
        try:
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="EC2 Instance Reboot Triggered",
                Message=message
            )
            logger.info("SNS notification sent.")
        except Exception as e:
            logger.error("Failed to send SNS notification: %s", str(e))

    return {
        "statusCode": 200,
        "body": json.dumps({"message": message})
    }
