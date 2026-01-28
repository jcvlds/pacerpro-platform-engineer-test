# Monitoring and Infrastructure Provisioning Solution for PacerPro

## Overview
Per the assessment, this solution will detect slow response times from a web app using Sumo Logic and will trigger an alert that invokes an AWS Lambda function to reboot the corresponding EC2 instance, and send an SNS notification.


## Assumptions & Deviations
1. I will do the Sumo Logic part of the assessment at the end because I want to first provision my AWS resources with Terraform so that I can then install the Sumo Logic 'Installed Collector' on the EC2 and have a demo for the real alert + trigger.
2. Already have AWS networking (VPC, subnets, security groups, etc) provisioned in our account and won't include these in the scope of this assessment's IAC
3. Configuring the Sumo Logic alert manually in the Sumo UI
4. I am making up the JSON structure of the logs. This will include the instance-id, count of entries that > 3000ms, and timeslice (10m)
5. Our SL alert+query will trigger our lambda for each instance (right now only 1, but could have more) having latency issues, and thus reboot that corresponding EC2
6. Sumo Logic will use Lambda Function URL to trigger with secure IAM (access key + secret)


# Video - Demo
- Full working demo at the end of Sumo Logic query+alert triggering our Lambda via its function url and in turn restarting our EC2 and publishing an SNS notification. 

- The infrastructure is fully managed by Terraform with least privilege access (IAM).

- Using Sumo Logic Trial Account