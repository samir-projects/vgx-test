#!/bin/bash
set -e
# Update and Upgrade the server
apt update -y && apt upgrade -y

# Download the k3s install script and install k3s
curl -sfL https://get.k3s.io | sh -

#Download and install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

#Add helm repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Set KUBECONFIG environment variable
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml 
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /etc/profile.d/k3s.sh

# Install nginx using helm
helm install my-nginx bitnami/nginx --set service.type=LoadBalancer

# Wait for the nginx pod to be in running state
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=nginx -n default --timeout=120s

# Add alias for kubectl

### Add kubectl alias for convenience
echo "alias k='kubectl'" >> /etc/profile.d/k3s.sh
source /etc/profile.d/k3s.sh

echo "http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):30080"