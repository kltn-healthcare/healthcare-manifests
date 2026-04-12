#!/bin/bash

# 1. Fetch Cluster Info
SERVER=$(kubectl config view --minify --output jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(kubectl config view --minify --output jsonpath='{.clusters[0].name}')
CA=$(kubectl config view --minify --flatten --output jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# 2. Generate Long-lived Token (10 years)
TOKEN=$(kubectl create token jenkins-deployer --namespace kube-system --duration=87600h)

# 3. Assemble Kubeconfig File
cat <<EOF > jenkins-kubeconfig.conf
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    certificate-authority-data: ${CA}
    server: ${SERVER}
contexts:
- name: jenkins-context
  context:
    cluster: ${CLUSTER_NAME}
    user: jenkins-deployer
users:
- name: jenkins-deployer
  user:
    token: ${TOKEN}
current-context: jenkins-context
EOF

echo "Success! Please upload 'jenkins-kubeconfig.conf' to Jenkins Credentials as a 'Secret File'."