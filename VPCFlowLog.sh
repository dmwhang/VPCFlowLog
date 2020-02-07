#!/bin/bash

available_regions=$(aws ec2 describe-regions | grep "RegionName" | tr -d "\" ")
available_regions=${available_regions//RegionName:/}

if [[ ${2} != "disable" ]]; then
    sls deploy
fi

for region in ${available_regions}
do
    if [[ ${2} == "disable" ]]; then
        aws cloudformation delete-stack \
            --region ${region} \
            --stack-name vpc-flow-log-stack-${region}
        aws lambda remove-permission \
            --statement-id ${region}-trigger \
            --function-name arn:aws:lambda:us-east-1:${1}:function:VPCFlowLog-dev-VPCFlowLogEnable
    else
        aws cloudformation create-stack --template-body file://global-stack.yaml --capabilities CAPABILITY_IAM \
            --region ${region} \
            --stack-name vpc-flow-log-stack-${region}
        if [[ ${2} != "enable" ]]; then
            python3 vpc_flow_log_boot.py ${region}
        fi
    fi
done

for region in ${available_regions}; do
    if [[ ${2} != "disable" ]]; then
        if [[ ${region} == "us-east-1" ]]; then
            topic=$(aws sns list-topics --region ${region} | grep "arn:aws:sns:${region}:${1}:VPCFlowLogTopic-${region}")
            while [[ ${topic} == "" ]]; do
                sleep 1
                topic=$(aws sns list-topics --region ${region} | grep "arn:aws:sns:${region}:${1}:VPCFlowLogTopic-${region}")
            done
        fi
        aws lambda add-permission  --action lambda:InvokeFunction --principal sns.amazonaws.com \
            --statement-id ${region}-trigger \
            --function-name arn:aws:lambda:us-east-1:${1}:function:VPCFlowLog-dev-VPCFlowLogEnable \
            --source-arn arn:aws:sns:${region}:${1}:VPCFlowLogTopic-${region}
    fi
done

if [[ ${2} == "disable" ]]; then
    aws s3 rb s3://ironnet-vpc-flow-log-${1} --force  --profile ${1}
    sls remove
fi
