#!/usr/bin/env bash

set -ex

# Create a namespace for our web application
kubectl create namespace web-app

# Create the web-service deployment and service
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-service
  namespace: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-service
  template:
    metadata:
      labels:
        app: web-service
    spec:
      containers:
      - name: web
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: web-config
          mountPath: /usr/share/nginx/html
      volumes:
      - name: web-config
        configMap:
          name: web-content
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: web-app
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: web-service
EOF

# Create ConfigMap with sample content
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: web-app
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <body>
      <h1>Web Application Content</h1>
      <p>This is the web front-end service.</p>
    </body>
    </html>
EOF

# Generate a self-signed certificate and key
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=gateway.web.k8s.local" \
  -addext "subjectAltName = DNS:gateway.web.k8s.local"

# Create the TLS secret in Kubernetes
kubectl create secret tls web-tls-secret \
  --cert=tls.crt \
  --key=tls.key \
  --namespace=web-app

# Verify the secret was created
kubectl get secret web-tls-secret -n web-app

# Create the Ingress Controller and Ingress Resource
wget https://get.helm.sh/helm-v4.0.4-darwin-amd64.tar.gz
tar -zxf helm-v4.0.4-darwin-amd64.tar.gz
mv darwin-amd64/helm /usr/local/bin
rm helm-v4.0.4-darwin-amd64.tar.gz
rm -rf darwin-amd64

helm install ingress-nginx \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http=30082 \
    --set controller.service.nodePorts.https=30443 \
    --repo https://kubernetes.github.io/ingress-nginx \
    ingress-nginx

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: web-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - gateway.web.k8s.local
    secretName: web-tls-secret
  rules:
  - host: gateway.web.k8s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
EOF

# Verify the Ingress resource
kubectl get ingress -n web-app