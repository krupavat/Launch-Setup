#!/bin/bash
#./cleanup.sh

declare -a EC2INSTANCES

mapfile -t EC2INSTANCES < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --security-group-ids $4  --subnet-id $5 --key-name $6 --iam-instance-profile Name=$7 --associate-public-ip-address --user-data file:///home/krupavat/Documents/gitProjects/MP1/Environment-Setup/install-env.sh --output table | grep InstanceId | sed "s/|//g" | sed "s/ //g" | sed "s/InstanceId//g")

echo ${EC2INSTANCES[@]}

aws ec2 wait instance-running --instance-ids ${EC2INSTANCES[@]}

ELBURL=(`aws elb create-load-balancer --load-balancer-name KSR-LB --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $5 --security-groups $4`)
sleep 25
aws elb register-instances-with-load-balancer --load-balancer-name KSR-LB --instances ${EC2INSTANCES[@]}

aws elb configure-health-check --load-balancer-name KSR-LB --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

aws autoscaling create-launch-configuration --launch-configuration-name ksr-mp1-launch-config --image-id $1 --key-name $6  --security-groups $4 --instance-type $3 --user-data file:///home/krupavat/Documents/gitProjects/MP1/Environment-Setup/install-env.sh --iam-instance-profile $7

aws autoscaling create-auto-scaling-group --auto-scaling-group-name ksr-mp1-auto-scaling-group --launch-configuration-name ksr-mp1-launch-config --load-balancer-names KSR-LB --health-check-type ELB --min-size 1 --max-size 3 --desired-capacity 2 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $5


aws rds create-db-subnet-group --db-subnet-group-name ksr-db-subnet-grp --db-subnet-group-description "db subnet group for mp1" --subnet-ids subnet-f8def0a1 subnet-3ad78b11

aws rds create-db-instance --db-name KSRDB --db-instance-identifier ksrmp1db --db-instance-class db.t1.micro --db-subnet-group-name ksr-db-subnet-grp --engine MySQL --master-username krupavat --master-user-password Admin123 --allocated-storage 16 --publicly-accessible


aws rds wait db-instance-available --db-instance-identifier ksrmp1db

#aws rds create-db-instance-read-replica --db-instance-identifier ReadRepksrmp1db --source-db-instance-identifier ksrmp1db --db-instance-class db.t1.micro


#aws cloudwatch put-metric-alarm --alarm-name ksrcwm --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroup,Value=itmo-544-extended-auto-scaling-group-2" --evaluation-periods 1 --alarm-actions arn:aws:autoscaling:us-east-1:681875787250:scalingPolicy:aeb16e5a-0e52-4eff-aa17-f7f7c5efcbe2:autoScalingGroupName/itmo-544-extended-auto-scaling-group-2:policyName/AravindScalingPolicy
