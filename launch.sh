
#./cleanup.sh

declare -a EC2INSTANCES

mapfile -t EC2INSTANCES < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3 --security-group-ids $4  --subnet-id $5 --key-name $6 --iam-instance-profile Name=$7 --user-data file://../Environment-setup/install-env.sh --output table | grep InstanceId | sed "s/|//g" | sed "s/ //g" | sed "s/InstanceId//g")

echo ${EC2INSTANCES[@]}

aws ec2 wait instance-running --instance-ids ${EC2INSTANCES[@]}

ELBURL=(`aws elb create-load-balancer --load-balancer-name KSR-LB --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $5 --security-groups $4`)
sleep 25
aws elb register-instances-with-load-balancer --load-balancer-name KSR-LB --instances ${EC2INSTANCES[@]}

aws elb configure-health-check --load-balancer-name KSR-LB --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

aws autoscaling create-launch-configuration --launch-configuration-name ksr-mp1-launch-config --image-id $1 --key-name $6  --security-groups $4 --instance-type $3 --user-data file://../Environment-setup/install-env.sh --iam-instance-profile $7

aws autoscaling create-auto-scaling-group --auto-scaling-group-name ksr-mp1-auto-scaling-group --launch-configuration-name ksr-mp1-launch-config --load-balancer-names KSR-LB --health-check-type ELB --min-size 1 --max-size 3 --desired-capacity 2 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $5

#aws rds create-db-instance --db-name KSRDB --db-instance-identifier ksrmp1db --allocated-storage 16 --db-instance-class db.t1.micro --engine MySQL --master-username krupavat --master-user-password Admin123  

#aws rds create-db-instance-read-replica --db-instance-identifier ReadRepksrmp1db --source-db-instance-identifier ksrmp1db --db-instance-class db.t1.micro
