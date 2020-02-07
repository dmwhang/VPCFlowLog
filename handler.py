import boto3

def vpc_flow_log_enable(event, context):
    if "boot_vpc_logs" != context:
        event = event['Records'][0]['Sns']['Message'].split(",")
    region = event[0].strip('"')
    vpc_id = event[1].strip('"\n')
    # format =
    session = boto3.Session(region_name=region)
    ec2 = session.client('ec2')
    sts = session.client('sts')
    cw = session.client('logs')

    name = 'ironnet-vpc-flow-log-'+str(sts.get_caller_identity().get('Account'))
    bucket_arn = "arn:aws:s3:::" + name
    s3_flow_log = ec2.create_flow_logs(
        ResourceIds=[str(vpc_id)],
        ResourceType='VPC',
        TrafficType='ALL',
        LogDestinationType='s3',
        LogDestination=bucket_arn
        # LogFormat=format
    )

    log_name = name+"/"+region+'/'+str(vpc_id)
    cw.create_log_group(logGroupName=log_name)
    cw_flow_log = ec2.create_flow_logs(
        DeliverLogsPermissionArn="arn:aws:iam::"+str(sts.get_caller_identity().get('Account'))+":role/ironnet-vpc-flow-logs-role",
        ResourceIds=[str(vpc_id)],
        ResourceType='VPC',
        TrafficType='ALL',
        LogDestinationType='cloud-watch-logs',
        LogGroupName=log_name
        # LogFormat=format
    )

    return s3_flow_log, cw_flow_log
