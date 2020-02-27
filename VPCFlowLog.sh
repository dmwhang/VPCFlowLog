#!/bin/bash

#vpc both enable
#vpc both enable 123
#vpc both disable
#vpc both disable 123
#vpc cw enable
#vpc cw enable 123
#vpc cw disable
#vpc cw disable 123
#vpc s3 enable
#vpc s3 enable 123
#vpc s3 disable
#vpc s3 disable 123


if [[ $1 != "cw" && $1 != "s3" && $1 != "both" ]]; then
    echo ERROR: 1st argument must either be "cw" or "s3" or "both"
    exit 1
elif [[ $2 != "enable" && $2 != "disable" ]]; then
    echo ERROR: 2nd argument must either be "enable" or "disable"
    exit 1
fi

if [[ $# == 2 ]]; then
    accounts=$(cat ~/.aws/credentials | grep "\[[0-9]*\]" | sed -e 's/\[//' -e 's/\]$//')
else
    input=($@)
    accounts=${input[@]:2}
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

for prof in ${accounts}
do
    export AWS_PROFILE=${prof}
    if [[ ${2} != "disable" ]]; then
        sls deploy
    fi

    for region in ${available_regions}
    do
        if [[ ${2} == "disable" ]]; then
            output=$(aws cloudformation delete-stack \
                --region ${region} \
                --stack-name vpc-flow-log-stack-${region})
            if [ $? -ne 0 ]; then
                echo ${output}
            fi
            if [[ $1 == "s3" || $1 == "both" ]]; then
                output=$(aws lambda remove-permission \
                    --region us-east-1 \
                    --statement-id ${region}-trigger \
                    --function-name arn:aws:lambda:us-east-1:${prof}:function:VPCFlowLog-dev-VPCFlowLogEnableS3)
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            fi
            if [[ $1 == "cw" || $1 == "both"  ]]; then
                output=$(aws lambda remove-permission \
                    --region us-east-1 \
                    --statement-id ${region}-trigger \
                    --function-name arn:aws:lambda:us-east-1:${prof}:function:VPCFlowLog-dev-VPCFlowLogEnableCW)
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            fi
        else
            output=$(aws cloudformation create-stack --template-body file://global-stack.yaml --capabilities CAPABILITY_IAM \
                --region ${region} \
                --stack-name vpc-flow-log-stack-${region} \
                --parameters ${cloud_params})
            if [ $? -ne 0 ]; then
                echo ${output}
            fi
            python3 VPCFlowLogBoot.py ${region} ${cloud_params}
        fi
    done

    if [[ ${2} != "disable" ]]; then
        for region in ${available_regions}; do
            if [[ ${region} == "us-east-1" ]]; then
                topic=$(aws sns list-topics --region ${region} | grep "arn:aws:sns:${region}:${prof}:VPCFlowLogTopic-${region}")
                while [[ ${topic} == "" ]]; do
                    sleep 1
                    topic=$(aws sns list-topics --region ${region} | grep "arn:aws:sns:${region}:${prof}:VPCFlowLogTopic-${region}")
                done
            fi
            if [[ $1 == "s3" || $1 == "both" ]]; then
                output=$(aws lambda add-permission  --action lambda:InvokeFunction --principal sns.amazonaws.com \
                    --statement-id ${region}-trigger \
                    --region us-east-1 \
                    --function-name arn:aws:lambda:us-east-1:${prof}:function:VPCFlowLog-dev-VPCFlowLogEnableS3 \
                    --source-arn arn:aws:sns:${region}:${prof}:VPCFlowLogTopic-${region})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            fi
            if [[ $1 == "cw" || $1 == "both"  ]]; then
                output=$(aws lambda add-permission  --action lambda:InvokeFunction --principal sns.amazonaws.com \
                    --statement-id ${region}-trigger \
                    --region us-east-1 \
                    --function-name arn:aws:lambda:us-east-1:${prof}:function:VPCFlowLog-dev-VPCFlowLogEnableCW \
                    --source-arn arn:aws:sns:${region}:${prof}:VPCFlowLogTopic-${region})
                if [ $? -ne 0 ]; then
                    echo ${output}
                fi
            fi
        done
    fi

    if [[ ${2} == "disable" ]]; then
        if [[ ${1} == "s3" || ${1} == "both" ]]; then
            aws s3 rm s3://ironnet-vpc-flow-log-${prof} --recursive
            aws s3 rb s3://ironnet-vpc-flow-log-${prof} --force
        fi
        sls remove
    fi
done
