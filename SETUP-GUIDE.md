# Jenkins Pipeline Setup Guide for Spring Boot Microservices

This guide will walk you through setting up a complete CI/CD pipeline for deploying Spring Boot microservices to AWS EKS.

---

## 📁 Project Structure

Your microservice repository should have this structure:

```
your-microservice/
├── src/
│   └── main/
│       ├── java/
│       └── resources/
│           └── application.yml
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── secret.yaml
├── Jenkinsfile
├── Dockerfile
├── pom.xml (or build.gradle)
├── .gitignore
└── README.md
```

**For hairstyle-user-service, the structure is:**
```
hairstyle-user-service/
├── src/
│   └── main/
│       ├── java/
│       └── resources/
│           └── application.yml
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── secret.yaml
├── Jenkinsfile
├── Dockerfile
├── pom.xml (or build.gradle)
├── .gitignore
└── README.md
```

---

## 🔧 Step 1: Configure Jenkins Credentials

### 1.1 Docker Hub Credentials
1. Go to Jenkins Dashboard → Manage Jenkins → Credentials
2. Click "Global" → "Add Credentials"
3. Select **Username with password**
4. Fill in:
    - **Username**: Your Docker Hub username
    - **Password**: Your Docker Hub password or access token
    - **ID**: `dockerhub-credentials`
    - **Description**: Docker Hub Credentials
5. Click "Create"

### 1.2 AWS Credentials
1. Go to Credentials → Add Credentials
2. Select **AWS Credentials**
3. Fill in:
    - **Access Key ID**: Your AWS access key
    - **Secret Access Key**: Your AWS secret key
    - **ID**: `aws-credentials`
    - **Description**: AWS Credentials for EKS
4. Click "Create"

### 1.3 GitHub Credentials (if private repository)
1. Go to Credentials → Add Credentials
2. Select **Username with password** or **SSH Username with private key**
3. Fill in:
    - **ID**: `github-credentials`
    - **Description**: GitHub Credentials
4. Click "Create"

---

## 🚀 Step 2: Prepare Your Microservice Repository

### 2.1 Add Required Files

Copy all the generated files to your microservice repository:

- `Jenkinsfile` → root directory
- `Dockerfile` → root directory
- `k8s/*.yaml` → k8s directory
- `.gitignore` → root directory
- `application.yml` → src/main/resources/

### 2.2 Update Configuration Files

#### Update `Jenkinsfile`:
```groovy
environment {
    DOCKER_HUB_REPO = 'your-actual-dockerhub-username'  // ⚠️ CHANGE THIS
    IMAGE_NAME = 'hairstyle-user-service'                // Already set
    // ... rest remains same
}
```

#### Update `k8s/configmap.yaml`:
```yaml
data:
  # Replace with your actual RDS endpoint from: terraform output rds_address
  SPRING_DATASOURCE_URL: "jdbc:postgresql://YOUR-RDS-ENDPOINT:5432/appdb"
```

Get your RDS endpoint:
```bash
cd terraform-directory
terraform output rds_address
```

#### Update `k8s/secret.yaml`:
```yaml
stringData:
  db-username: "dbadmin"           # ⚠️ CHANGE THIS (match Terraform)
  db-password: "YourPassword123!"  # ⚠️ CHANGE THIS (match Terraform)
```

**IMPORTANT**: Add `k8s/secret.yaml` to `.gitignore` before committing!

### 2.3 Update Spring Boot Application

Ensure your `pom.xml` includes these dependencies:

```xml
<dependencies>
    <!-- Spring Boot Starter Web -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    
    <!-- Spring Boot Starter Data JPA -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    
    <!-- PostgreSQL Driver -->
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <scope>runtime</scope>
    </dependency>
    
    <!-- Spring Boot Actuator (for health checks) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
</dependencies>
```

---

## 📝 Step 3: Create Jenkins Pipeline Job

### 3.1 Create New Pipeline Job
1. Go to Jenkins Dashboard
2. Click "New Item"
3. Enter name: `hairstyle-user-service-pipeline`
4. Select "Pipeline"
5. Click "OK"

### 3.2 Configure Pipeline
1. In "Pipeline" section:
    - **Definition**: Pipeline script from SCM
    - **SCM**: Git
    - **Repository URL**: Your GitHub repository URL
    - **Credentials**: Select `github-credentials` (if private repo)
    - **Branch**: `*/main` or `*/master`
    - **Script Path**: `Jenkinsfile`
2. Click "Save"

### 3.3 Optional: Configure Triggers
In the job configuration, you can enable:
- **Poll SCM**: `H/5 * * * *` (checks every 5 minutes)
- **GitHub hook trigger** for automatic builds on push

---

## 🎯 Step 4: First Deployment

### 4.1 Verify Jenkins Has Access to EKS

Test AWS CLI access from Jenkins:
1. Go to your Jenkins job → "Build Now"
2. Click "Console Output"
3. Verify the "Configure kubectl" stage succeeds

### 4.2 Update RDS Security Group (if needed)

Ensure EKS nodes can access RDS:
```bash
# Get EKS node security group
kubectl get nodes -o wide

# Your Terraform already configured this, but verify:
terraform output eks_cluster_security_group_id
```

### 4.3 Run the Pipeline
1. Click "Build Now"
2. Monitor the build in "Console Output"
3. Wait for all stages to complete (takes ~5-10 minutes first time)

### 4.4 Verify Deployment
```bash
# Configure kubectl locally
aws eks update-kubeconfig --region eu-west-2 --name springboot-eks-cluster

# Check pods
kubectl get pods

# Check service
kubectl get svc

# Get Load Balancer URL
kubectl get svc springboot-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 4.5 Test Your Application
```bash
# Get the external URL
export APP_URL=$(kubectl get svc hairstyle-user-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$APP_URL/actuator/health

# Test your API endpoints
curl http://$APP_URL/api/users
curl http://$APP_URL/api/hairstyles
```

---

## 🔄 Step 5: Make It Reusable for Multiple Microservices

### 5.1 Create a Shared Library (Advanced)

For multiple microservices, create a Jenkins Shared Library:

1. Create a new Git repository: `jenkins-shared-library`
2. Structure:
```
jenkins-shared-library/
└── vars/
    └── deployMicroservice.groovy
```

3. Add to `vars/deployMicroservice.groovy`:
```groovy
def call(Map config) {
    pipeline {
        agent any
        environment {
            DOCKER_HUB_REPO = config.dockerHubRepo
            IMAGE_NAME = config.imageName
            APP_NAME = config.appName
            // ... use config parameters
        }
        stages {
            // Use the same stages from Jenkinsfile
        }
    }
}
```

4. In each microservice, use:
```groovy
@Library('jenkins-shared-library') _

deployMicroservice(
    dockerHubRepo: 'your-dockerhub-username',
    imageName: 'microservice-name',
    appName: 'microservice-name'
)
```

### 5.2 Alternative: Template Repository

Create a template repository with all files, then:
1. Clone template for each new microservice
2. Update `IMAGE_NAME` and `APP_NAME` in Jenkinsfile
3. Update K8s manifests with new service name
4. Push to new repository

---

## 🔐 Security Best Practices

1. **Never commit secrets to Git**
    - Add `k8s/secret.yaml` to `.gitignore`
    - Use AWS Secrets Manager or HashiCorp Vault in production

2. **Use RBAC for Jenkins**
    - Create dedicated service account for Jenkins
    - Limit permissions to only what's needed

3. **Scan Docker images**
    - Add security scanning stage in pipeline
    - Use tools like Trivy or Snyk

4. **Use private Docker registry**
    - Consider AWS ECR instead of Docker Hub
    - Better integration with AWS services

---

## 🐛 Troubleshooting

### Pipeline Fails at "Configure kubectl"
- Check AWS credentials in Jenkins
- Verify EKS cluster name matches
- Ensure Jenkins has AWS CLI v2 installed

### Cannot Connect to RDS
- Check security group allows traffic from EKS nodes
- Verify RDS endpoint in configmap.yaml
- Check credentials in secret.yaml

### Pods Not Starting
```bash
# Check pod logs
kubectl logs -l app=springboot-app

# Describe pod for events
kubectl describe pod <pod-name>

# Common issues:
# - Wrong database credentials
# - RDS endpoint incorrect
# - Image pull errors (check Docker Hub credentials)
```

### Load Balancer Not Created
```bash
# Check service events
kubectl describe svc springboot-app

# Verify AWS Load Balancer Controller is installed (should be automatic with EKS)
```

---

## 📊 Monitoring Your Application

### View Application Logs
```bash
kubectl logs -f -l app=springboot-app
```

### Access Actuator Endpoints
```bash
# Health check
curl http://$APP_URL/actuator/health

# Metrics
curl http://$APP_URL/actuator/metrics

# Info
curl http://$APP_URL/actuator/info
```

### Scale Your Application
```bash
# Scale to 3 replicas
kubectl scale deployment springboot-app --replicas=3

# Or update deployment.yaml and re-run pipeline
```

---

## 🎉 Next Steps

1. **Add More Microservices**: Repeat this process for each microservice
2. **Implement Service Mesh**: Consider Istio or AWS App Mesh
3. **Add Monitoring**: Set up Prometheus and Grafana
4. **Implement GitOps**: Consider ArgoCD or Flux
5. **Add API Gateway**: Use Kong or AWS API Gateway

---

## 📚 Additional Resources

- [Spring Boot Actuator Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)