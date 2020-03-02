#!/bin/bash

if [[ $1 != "cw" && $1 != "s3" && $1 != "both" ]]; then
    echo ERROR: 1st argument must either be "cw" or "s3" or "both"
    exit 1
elif [[ $2 != "enable" && $2 != "disable" ]]; then
    echo ERROR: 2nd argument must either be "enable" or "disable"
    exit 1
fi

case $1 in
    s3)
        cloud_params="ParameterKey=S3,ParameterValue=true ParameterKey=CW,ParameterValue=false"
        ;;
    cw)
        cloud_params="ParameterKey=S3,ParameterValue=false ParameterKey=CW,ParameterValue=true"
        ;;
    *)
        cloud_params="ParameterKey=S3,ParameterValue=true ParameterKey=CW,ParameterValue=true"
        ;;
esac

available_regions=$(aws --region us-east-1 ec2 describe-regions | jq -r ".Regions[].RegionName")
profile=$(aws sts get-caller-identity | jq -r ".Account")

if [[ ${2} == "enable" ]]; then
    ./node_modules/serverless/bin/serverless deploy
fi

for region in ${available_regions}; do
    if [[ ${2} == "enable" ]]; then
        echo Deploying stacks and flow logs in region: ${region}
        output=$(aws cloudformation create-stack --template-body file://global-stack.yaml --capabilities CAPABILITY_IAM \
            --region ${region} \
            --stack-name vpc-flow-log-stack-${region} \
            --parameters ${cloud_params})
        if [ $? -ne 0 ]; then
            echo ${output}
        fi
        vpcs=$(aws ec2 describe-vpcs --region ${region} | jq -r ".Vpcs[].VpcId")
        if [ $? -ne 0 ]; then
            echo ${vpcs}
        fi
        for vpc_id in ${vpcs}; do
            if [[ $1 != "cw" ]]; then
                output=$(aws ec2 create-flow-logs \
                    --region ${region} \
                    --resource-ids ${vpc_id} \
                    --resource-type VPC \
                    --traffic-type ALL \
                    --log-destination-type s3 \
                    --log-destination arn:aws:s3:::ironnet-vpc-flow-log-${profile})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            fi
            if [[ $1 != "s3" ]]; then
                output=$(aws logs create-log-group \
                    --region ${region} \
                    --log-group-name ironnet-vpc-flow-log-${profile}/${region}/${vpc_id})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
                output=$(aws ec2 create-flow-logs \
                    --region ${region} \
                    --deliver-logs-permission-arn arn:aws:iam::${profile}:role/ironnet-vpc-flow-logs-role \
                    --resource-ids ${vpc_id} \
                    --resource-type VPC \
                    --traffic-type ALL \
                    --log-destination-type cloud-watch-logs \
                    --log-group-name ironnet-vpc-flow-log-${profile}/${region}/${vpc_id})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            fi
        done
    else
        echo Clearing cloudformation stacks and lambda permissions in region: ${region}
        output=$(aws cloudformation delete-stack \
            --region ${region} \
            --stack-name vpc-flow-log-stack-${region})
        if [ $? -ne 0 ]; then
            echo ${output}
        fi
        if [[ $1 != "cw" ]]; then
            output=$(aws lambda remove-permission \
                --region us-east-1 \
                --statement-id s3-${region}-trigger \
                --function-name arn:aws:lambda:us-east-1:${profile}:function:VPCFlowLog-dev-VPCFlowLogEnableS3)
            if [ $? -ne 0 ]; then
                echo ${output}
            fi
        fi
        if [[ $1 != "s3" ]]; then
            output=$(aws lambda remove-permission \
                --region us-east-1 \
                --statement-id cw-${region}-trigger \
                --function-name arn:aws:lambda:us-east-1:${profile}:function:VPCFlowLog-dev-VPCFlowLogEnableCW)
            if [ $? -ne 0 ]; then
                echo ${output}
            fi
        fi
    fi
done

for region in ${available_regions}; do
    if [[ ${2} == "enable" ]]; then
        echo Deploying sns topics and lambda permissions in region: ${region}
        if [[ ${region} == "us-east-1" ]]; then
            topic=$(aws sns list-topics --region ${region} | grep "arn:aws:sns:${region}:${profile}:VPCFlowLogTopic-${region}")
            while [[ ${topic} == "" ]]; do
                sleep 1
                topic=$(aws sns list-topics --region ${region} | grep "arn:aws:sns:${region}:${profile}:VPCFlowLogTopic-${region}")
            done
        fi
        if [[ $1 != "cw" ]]; then
            output=$(aws lambda add-permission  --action lambda:InvokeFunction --principal sns.amazonaws.com \
                --statement-id s3-${region}-trigger \
                --region us-east-1 \
                --function-name arn:aws:lambda:us-east-1:${profile}:function:VPCFlowLog-dev-VPCFlowLogEnableS3 \
                --source-arn arn:aws:sns:${region}:${profile}:VPCFlowLogTopic-${region})
            if [ $? -ne 0 ]; then
                echo ${output}
            fi
        fi
        if [[ $1 != "s3" ]]; then
            output=$(aws lambda add-permission  --action lambda:InvokeFunction --principal sns.amazonaws.com \
                --statement-id cw-${region}-trigger \
                --region us-east-1 \
                --function-name arn:aws:lambda:us-east-1:${profile}:function:VPCFlowLog-dev-VPCFlowLogEnableCW \
                --source-arn arn:aws:sns:${region}:${profile}:VPCFlowLogTopic-${region})
            if [ $? -ne 0 ]; then
                echo ${output}
            fi
        fi
    else
        echo Clearing flow logs in region: ${region}
        if [[ $1 != "cw" ]]; then
            search=".FlowLogs[] | select(.LogDestination == \"arn:aws:s3:::ironnet-vpc-flow-log-${profile}\")"
            flow_logs=$(aws --region ${region} ec2 describe-flow-logs | \
                jq "${search}" | \
                jq -r '.FlowLogId')
            if [ $? -ne 0 ]; then
                echo ${flow_logs}
            fi
            for flow_log_id in ${flow_logs}; do
                output=$(aws ec2 delete-flow-logs \
                    --region ${region} \
                    --flow-log-id ${flow_log_id})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            done
        fi
        if [[ $1 != "s3" ]]; then
            vpcs=$(aws ec2 describe-vpcs --region ${region} | jq -r ".Vpcs[].VpcId")
            if [ $? -ne 0 ]; then
                echo ${vpcs}
            fi
            for vpc_id in ${vpcs}; do
                output=$(aws logs delete-log-group \
                    --region ${region} \
                    --log-group-name ironnet-vpc-flow-log-${profile}/${region}/${vpc_id})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            done
            search=".FlowLogs[] | select(.DeliverLogsPermissionArn == \"arn:aws:iam::${profile}:role/ironnet-vpc-flow-logs-role\")"
            flow_logs=$(aws --region ${region} ec2 describe-flow-logs | \
                jq "${search}" | \
                jq -r '.FlowLogId')
            if [ $? -ne 0 ]; then
                echo ${flow_logs}
            fi
            for flow_log_id in ${flow_logs}; do
                output=$(aws ec2 delete-flow-logs \
                    --region ${region} \
                    --flow-log-id ${flow_log_id})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            done
        fi
    fi
done

if [[ ${2} == "disable" ]]; then
    if [[ ${1} != "cw" ]]; then
        aws s3 rm s3://ironnet-vpc-flow-log-${profile} --recursive
        aws s3 rb s3://ironnet-vpc-flow-log-${profile} --force
    fi
    ./node_modules/serverless/bin/serverless remove
fi
