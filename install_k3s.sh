#!/bin/bash
k3s_installation_link="https://get.k3s.io"
helm_installtion_link="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
helm_file="get_helm.sh"
helm_link_nginx="https://charts.bitnami.com/bitnami"
kube_config_path="/etc/rancher/k3s/k3s.yaml"
kube_bash_profile="/etc/profile.d/k3s.sh"
helm_link_prometheus="https://prometheus-community.github.io/helm-charts"
kube_namespace="monitoring"
helm_update_command="helm repo update"
target_port_prometheus=9090
target_port_grafana=3000
nodeport_prometheus=31000
nodeport_grafana=32000

set -e
echo "Updating and Upgrading the server"
apt update -y && apt upgrade -y

echo "Downloading the k3s install script and install k3s"
curl -sfL $k3s_installation_link | sh -

echo "Download and install helm"
curl -fsSL -o $helm_file $helm_installtion_link
chmod 700 $helm_file
./$helm_file

echo "Add helm repo nginx"
helm repo add bitnami $helm_link_nginx
$helm_update_command

echo "Set KUBECONFIG environment variable"
export KUBECONFIG=$kube_config_path
echo "export KUBECONFIG=$kube_config_path" >> $kube_bash_profile

echo "Install nginx using helm"
helm install my-nginx bitnami/nginx --set service.type=LoadBalancer

echo "Wait for the nginx pod to be in running state"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=nginx -n default --timeout=120s

echo "Add kubectl alias for convenience"
echo "alias k='kubectl'" >> $kube_bash_profile
source $kube_bash_profile

echo "Add helm repo for prometheus"
helm repo add prometheus-community $helm_link_prometheus
$helm_update_command

echo "Create monitoring namespace"
kubectl create namespace $kube_namespace

echo "Install prometheus using helm"
helm install prometheus prometheus-community/prometheus -n $kube_namespace

echo "Expose prometheus server using NodePort"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: prometheus-server-ext
  namespace: $kube_namespace
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: prometheus
  ports:
    - port: $target_port_prometheus
      targetPort: $target_port_prometheus
      nodePort: $nodeport_prometheus
EOF

echo "Add helm repo for Grafana"
helm repo add grafana https://grafana.github.io/helm-charts 
$helm_update_command

echo "Install Grafana using helm"
helm install grafana grafana/grafana -n $kube_namespace 

echo "Expose Grafana using NodePort"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: grafana-ext
  namespace: $kube_namespace
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: grafana
  ports:
    - port: $target_port_grafana
      targetPort: $target_port_grafana
      nodePort: $nodeport_grafana
EOF