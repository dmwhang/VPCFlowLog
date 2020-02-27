import handler
import boto3
import sys

session = boto3.Session(region_name=str(sys.argv[1]))
ec2 = session.client('ec2')
vpcs = ec2.describe_vpcs()['Vpcs']
if vpcs != []:
    for vpc in vpcs:
        print("Region:", str(sys.argv[1]), "Enabling flow log on vpc:", str(vpc['VpcId']))
        if 'true' in sys.argv[2]:
            handler.s3_vpc_flow_log_enable((str(sys.argv[1]), str(vpc['VpcId'])), "boot_vpc_logs")
        if 'true' in sys.argv[3]:
            handler.cw_vpc_flow_log_enable((str(sys.argv[1]), str(vpc['VpcId'])), "boot_vpc_logs")
