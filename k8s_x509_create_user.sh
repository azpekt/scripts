#!/bin/bash

NS=$1
USERNAME=$2

echo "..creating private key..."
openssl genrsa -out $USERNAME.pem 2048

echo "..creating CSR..."
openssl req -new -key $USERNAME.pem -out $USERNAME.csr -subj "/CN=$USERNAME"

echo "..getting encoded CSR..."
ENCODE=$(cat $USERNAME.csr  | base64 | tr -d '\n')

echo "..creating NS..."
kubectl create ns $NS

echo "..approving CSR..."

cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: csr-$USERNAME
spec:
  groups:
  - system:authenticated
  request: $ENCODE
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF
kubectl certificate approve csr-$USERNAME

echo "..getting certificate..."
kubectl get csr csr-$USERNAME  -o jsonpath='{.status.certificate}' | base64 --decode > $USERNAME.crt

echo "..creating and adding contexts...change the cluster name!"
kubectl config set-credentials $USERNAME --client-key=$USERNAME.pem --client-certificate=$USERNAME.crt
kubectl config set-context $USERNAME --cluster=kubernetes-the-hard-way --namespace=$NS --user=$USERNAME

echo "..creating rolebinging..."
kubectl create rolebinding rb-admin-$USERNAME --clusterrole=admin --user=$USERNAME --namespace=$NS
# kubectl create clusterrolebinding rb-admin-$USERNAME --clusterrole=cluster-admin --user=$USERNAME 
kubectl config use-context $USERNAME
