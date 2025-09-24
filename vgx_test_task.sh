#!/bin/bash
key_name=vgx-key
security_group_name=vgx-sg
directory=/home/samir/Desktop/vgx
ami_id=ami-0dd67d541aa70c8b9
instance_count=1
instance_type=t2.medium

set -e
## Check if keypair already exists 
existing_key=$(aws ec2 describe-key-pairs --key-names "$key_name" 2>/dev/null | jq -r '.KeyPairs[0].KeyName')
if [[ $existing_key == $key_name ]]; then 
    echo "$key_name already exists"
else
    keypairid=$(aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > $directory/$key_name.pem)
    echo "Keypair $key_name created"
fi
# Change key permission
chmod 400 $key_name.pem

# Create a Security Group and allow HTTP and SSH 
sg_id=$(aws ec2 create-security-group --group-name $security_group_name --description "Allow SSH and HTTP traffic" --query 'GroupId' --output text)
echo "Security group $security_group_name created"

echo "Opening Port 22"
aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0 2>/dev/null || true

echo "Opening port 80"
aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 80 --cidr 0.0.0.0/0 2>/dev/null || true

echo "Creating Ec2 instance"
aws ec2 run-instances --image-id $ami_id --count $instance_count --instance-type $instance_type --security-group-ids $sg_id --associate-public-ip-address --query 'Instances[0].InstanceId'  --user-data file://install_k3s.sh --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k3s-vgx}]' --output text
