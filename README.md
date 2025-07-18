# k0s-kubernetes
creating a single node k0s cluster. 

```
📡 External User (port 80/443 on EC2)
   ⬇️
🌐 EC2 Public IP
   ⬇️
🚪 Security Group allows port 80
   ⬇️
🚪 NGINX Ingress Controller (running on k8s, type=LoadBalancer or NodePort)
   ⬇️
🛣 Ingress object (routes / to quote-frontend)
   ⬇️
🧱 quote-frontend Service (ClusterIP)
   ⬇️
🚀 quote-frontend Pods (on port 80)
```
