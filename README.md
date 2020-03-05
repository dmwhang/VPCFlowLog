# VPCFlowLog

VPC flow logging in both S3 and Cloudwatch Log formats for preexisting VPCs as
well as any new VPC that is created

## Usage

### Configuration

Requires NPM, AWS CLI, and jq

Download the repo and run the following within that directory

### Setup

- You'll need write access to the AWS accounts that you run this against
- User has set credentials to the account they would like to enable flow logs in
    - Can use [IronNet SSO](https://ironnetsso.awsapps.com/start#/) 
    to export credentials to the environment by accessing 
    "Command line or programmatic access" for the appropriate account
- Install packages through npm
```bash
npm install
```
### Deploy

The first argument declares where to send the flow logs to:
- [s3] sends logs to an s3 bucket
- [cw] sends logs to a cloudwatch log
- [all] sends logs to both an s3 bucket and cloudwatch log

The second argument declares whether to enable or disable flow logging:
- [enable] enables flow logging and deploys resources
- [disable] disables flow logging and tears down all resources previously deployed

Run

    ./VPCFlowLog.sh [s3/cw/all] [enable/disable]

Example:

    ./VPCFlowLog.sh all enable

### Notes

- If deployment is unsucessful, run "disable" before trying to run "enable" again
- If serverless throws an error about "self signed certificate in certificate chain," 
user must grant NPM the proper certificates by [getting the proper certs](https://ironnet.atlassian.net/browse/CI-1883)
and then setting the appropriate environment variables temporarily or through your shell config file (.bash_profile, .bashrc, .zshrc, etc)

```bash
export SSL_CERT_FILE=[path to file]/allcerts.pem
export REQUESTS_CA_BUNDLE=[path to file]/allcerts.pem
export NODE_EXTRA_CA_CERTS=[path to file]/allcerts.pem
```

- If serverless throws an error about "local issuer certificates," run with company vpn enabled
- If user wants to change log format, they may do so in the handler.py file but they must
disable and then enable VPC flow logging after making edits to the handler.py

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
