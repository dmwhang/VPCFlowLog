# VPCFlowLog

VPC flow logging in both S3 and Cloudwatch Log formats for preexisting VPCs as
well as any new VPC that is created

## Usage

### Configuration

Install appropriate npm packages
```
$ npm install
```
Requires the AWS CLI and jq

### Setup

- You'll need write access to the AWS accounts that you run this against
- User has set credentials to the account they are running in

### Deploy

The first argument declares where to send the flow logs to:
- [s3] is for s3 bucket
- [cw] is for cloudwatch flog logging
- [both] is for both the above

The second argument declares whether to enable or disable flow logging:
- [enable] enables flow logging and deploys resources
- [disable] disables flow logging and tears down resources

Run

    ./VPCFlowLog.sh [s3/cw/both] [enable/disable]

Example:

    ./VPCFlowLog.sh both enable

## Resources Deployed

- CloudFormation Stack "VPCFlowLog-dev" in region "us-east-1" containing:
    - Lambda function: "VPCFlowLog-dev-[region]-lambdaRole"
    - Cloudwatch log group: "/aws/lambda/VPCFlowLog-dev-VPCFlowLogEnable"
    - S3 Bucket: "ironnet-vpc-flow-log-[Account ID]"
    - S3 Bucket: "vpcflowlog-dev-serverlessdeploymentbucket-[serverless specifc id]
    - IAM Role: "VPCFlowLog-dev-us-east-1-lambdaRole"
    - IAM Role: "ironnet-vpc-flow-logs-role"
- CloudFormation Stack "vpc-flow-log-stack-[region]" in every active region containing:
    - Cloudwatch rule: "VPCFlowLogRule-[region]"
    - SNS Topic: "arn:aws:sns:[region]:[Account ID]:VPCFlowLogTopic-[region]"

## Notes

- If serverless is unable to deploy, run with company vpn
- If user wants to change log format, they may do so in the handler.py file
