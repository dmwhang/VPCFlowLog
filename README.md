# VPCFlowLog

#### VPCFlowLog enables:

- VPC flow logging in both S3 and Cloudwatch Log formats for preexisting VPCs as well as any new VPC that is created
 
#### VPCFlowLog deploys:
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

## Usage

###Configuration

- Install and initialize npm
```
$ npm install
$ npm init
```
- Install serverless
```
$ npm install serverless
```
- Install python3 and boto3
```
$ brew install python3
$ pip install boto3
```

### Setup

- Account executing VPCFlowLog must have administrator access
- Environment variables are set to the appropriate account and region

### Deploy

Run

    ./deploy.sh [account id]
    
Example:

    ./delpoy.sh 123456789012
