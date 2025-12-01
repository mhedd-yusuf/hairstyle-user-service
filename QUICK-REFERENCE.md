# Quick Reference Guide

## 🚀 Common Commands

### Get RDS Endpoint from Terraform
```bash
cd /path/to/terraform
terraform output rds_address
terraform output rds_endpoint
```

### Configure kubectl for EKS
```bash
aws eks update-kubeconfig --region eu-west-2 --name springboot-eks-cluster
```

### Check Kubernetes Resources
```bash
# List all pods
kubectl get pods

# List all services
kubectl get svc

# List all deployments
kubectl get deployments

# Get detailed info
kubectl describe pod <pod-name>
kubectl describe svc hairstyle-user-service

# View logs
kubectl logs -f <pod-name>
kubectl logs -f -l app=hairstyle-user-service  # All pods with label
```

### Create Secret Manually (if not using secret.yaml)
```bash
kubectl create secret generic hairstyle-user-service-secret \
  --from-literal=db-username=dbadmin \
  --from-literal=db-password=YourPassword123! \
  -n default
```

### Update ConfigMap After RDS Changes
```bash
# Edit configmap
kubectl edit configmap hairstyle-user-service-config

# Or apply updated file
kubectl apply -f k8s/configmap.yaml
```

### Restart Deployment (after config changes)
```bash
kubectl rollout restart deployment hairstyle-user-service
```

### Scale Application
```bash
# Scale up
kubectl scale deployment hairstyle-user-service --replicas=3

# Scale down
kubectl scale deployment hairstyle-user-service --replicas=1
```

### Get Application URL
```bash
# Get LoadBalancer URL
kubectl get svc hairstyle-user-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Or with full command
export APP_URL=$(kubectl get svc hairstyle-user-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$APP_URL"
```

### Test Application
```bash
# Health check
curl http://$APP_URL/actuator/health

# Pretty print JSON
curl -s http://$APP_URL/actuator/health | jq .

# Your API endpoints
curl http://$APP_URL/api/your-endpoint
```

---

## 🔍 Debugging

### Check Pod Status
```bash
# If pod is in CrashLoopBackOff or Error
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Previous logs (if pod restarted)
kubectl logs <pod-name> --previous
```

### Check Database Connection
```bash
# Get a shell in the pod
kubectl exec -it <pod-name> -- /bin/sh

# Inside the pod, test database connection
apk add postgresql-client  # If not installed
psql -h YOUR-RDS-ENDPOINT -U dbadmin -d appdb
```

### Check if RDS is Accessible from EKS
```bash
# Create a test pod
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- bash

# Inside the pod
psql -h YOUR-RDS-ENDPOINT -U dbadmin -d appdb
```

### View All Resources in Namespace
```bash
kubectl get all
```

### Delete Resources (for cleanup)
```bash
# Delete deployment
kubectl delete deployment hairstyle-user-service

# Delete service
kubectl delete svc hairstyle-user-service

# Delete all resources with label
kubectl delete all -l app=hairstyle-user-service

# Delete ConfigMap and Secret
kubectl delete configmap hairstyle-user-service-config
kubectl delete secret hairstyle-user-service-secret
```

---

## 🔧 Jenkins Operations

### Trigger Build from CLI
```bash
# Using Jenkins CLI
java -jar jenkins-cli.jar -s http://your-jenkins-url/ build hairstyle-user-service-pipeline

# Using curl
curl -X POST http://your-jenkins-url/job/hairstyle-user-service-pipeline/build \
  --user username:token
```

### View Jenkins Build Logs
```bash
# SSH into Jenkins server
ssh your-jenkins-server

# View logs
docker logs jenkins  # If Jenkins in Docker
tail -f /var/log/jenkins/jenkins.log  # If installed directly
```

---

## 📊 Monitoring Commands

### Watch Pod Status in Real-time
```bash
kubectl get pods -w
```

### Monitor Resource Usage
```bash
# Top pods (requires metrics-server)
kubectl top pods

# Top nodes
kubectl top nodes
```

### View Events
```bash
# All events
kubectl get events --sort-by=.metadata.creationTimestamp

# Events for specific resource
kubectl get events --field-selector involvedObject.name=hairstyle-user-service
```

---

## 🔄 Update Deployment

### Method 1: Through Jenkins
1. Make code changes
2. Commit and push to GitHub
3. Jenkins automatically builds and deploys (if webhook configured)
4. Or manually click "Build Now" in Jenkins

### Method 2: Direct kubectl
```bash
# Update image to specific tag
kubectl set image deployment/hairstyle-user-service \
  hairstyle-user-service=your-dockerhub/hairstyle-user-service:123

# Check rollout status
kubectl rollout status deployment/hairstyle-user-service

# Rollback if needed
kubectl rollout undo deployment/hairstyle-user-service
```

### Method 3: Update YAML and Apply
```bash
# Edit deployment.yaml with new image tag
# Then apply
kubectl apply -f k8s/deployment.yaml
```

---

## 🗑️ Complete Cleanup

### Delete Kubernetes Resources
```bash
kubectl delete -f k8s/
# Or
kubectl delete all -l app=hairstyle-user-service
kubectl delete configmap hairstyle-user-service-config
kubectl delete secret hairstyle-user-service-secret
```

### Destroy Terraform Infrastructure
```bash
cd /path/to/terraform
terraform destroy

# If you want to keep some resources
terraform destroy -target=aws_eks_cluster.main
```

---

## 🔐 Security Commands

### Rotate Database Password
```bash
# 1. Update password in RDS
aws rds modify-db-instance \
  --db-instance-identifier springboot-app-postgres \
  --master-user-password NewPassword123! \
  --apply-immediately

# 2. Update Kubernetes secret
kubectl delete secret hairstyle-user-service-secret
kubectl create secret generic hairstyle-user-service-secret \
  --from-literal=db-username=dbadmin \
  --from-literal=db-password=NewPassword123!

# 3. Restart deployment
kubectl rollout restart deployment hairstyle-user-service
```

### View Secret (decoded)
```bash
kubectl get secret hairstyle-user-service-secret -o jsonpath='{.data.db-password}' | base64 -d
```

---

## 📈 Performance Tuning

### Adjust Resource Limits
```bash
# Edit deployment
kubectl edit deployment hairstyle-user-service

# Update resources section:
# resources:
#   requests:
#     memory: "512Mi"
#     cpu: "250m"
#   limits:
#     memory: "1Gi"
#     cpu: "500m"
```

### Configure HPA (Horizontal Pod Autoscaler)
```bash
kubectl autoscale deployment hairstyle-user-service \
  --cpu-percent=80 \
  --min=2 \
  --max=10
```

---

## 💡 Tips

1. **Always check logs first**: `kubectl logs -f <pod-name>`
2. **Use labels**: Makes filtering and bulk operations easier
3. **Keep backups**: Of your database and configurations
4. **Test locally first**: Use Docker Compose for local testing
5. **Monitor costs**: EKS nodes and RDS can be expensive

---

## 🆘 Emergency Procedures

### Application Not Responding
```bash
# 1. Check pod status
kubectl get pods

# 2. Check logs
kubectl logs -l app=hairstyle-user-service --tail=100

# 3. Restart deployment
kubectl rollout restart deployment hairstyle-user-service

# 4. If still failing, scale down and up
kubectl scale deployment hairstyle-user-service --replicas=0
kubectl scale deployment hairstyle-user-service --replicas=2
```

### Database Connection Lost
```bash
# 1. Check RDS status in AWS Console
# 2. Verify security groups
# 3. Test connection from pod
kubectl run -it --rm test-db --image=postgres:16 --restart=Never -- \
  psql -h YOUR-RDS-ENDPOINT -U dbadmin -d appdb
```

### Out of Memory / CPU
```bash
# Quick fix: Scale up resources
kubectl scale deployment hairstyle-user-service --replicas=4

# Long term: Update resource limits in deployment.yaml
```

---

## 📞 Support Resources

- AWS Support: https://console.aws.amazon.com/support/
- Kubernetes Slack: https://slack.k8s.io/
- Spring Boot Documentation: https://spring.io/projects/spring-boot
- Jenkins Community: https://www.jenkins.io/participate/