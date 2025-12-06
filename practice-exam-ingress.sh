# namespace
kubectl create ns demo

# backend 1 (HTTP, port 80)
kubectl create deploy app-http --image=nginx -n demo
kubectl expose deploy app-http --port=80 --target-port=80 -n demo

# backend 2 (HTTPS-style service, port 443)
kubectl create deploy app-https --image=nginx -n demo
kubectl expose deploy app-https --port=443 --target-port=80 -n demo

# self-signed cert for app.example.com
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -days 365 \
  -subj "/CN=app.example.com/O=App Example"

# tls secret
kubectl create secret tls app-tls \
  --cert=tls.crt --key=tls.key -n demo

# ingress with HTTP+HTTPS-style routes (same host/path, ports 80 and 443)
cat <<'EOF' > app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  namespace: demo
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-http
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-https
            port:
              number: 443
EOF

kubectl apply -f app-ingress.yaml
kubectl get ingress -n demo

