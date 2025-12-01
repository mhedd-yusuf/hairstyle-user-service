# EKS Infrastructure Terraform Project

This Terraform project creates a complete AWS EKS infrastructure for deploying microservices.

## Architecture Overview

This infrastructure includes:
- **VPC** with public, private, and database subnets across 3 AZs
- **EKS Cluster** (v1.28) with managed node groups
- **RDS PostgreSQL** instance in private subnet
- **ECR** repositories for Docker images
- **IAM roles** for IRSA (IAM Roles for Service Accounts)
- **AWS Load Balancer Controller** for ingress
- **Cluster Autoscaler** for automatic scaling
- **Metrics Server** for HPA support

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl
- Helm 3

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan Infrastructure

```bash
terraform plan
```

### 4. Apply Infrastructure

```bash
terraform apply
```

This will take approximately 15-20 minutes to complete.

### 5. Configure kubectl

After the infrastructure is created:

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region us-east-1
```

### 6. Verify Cluster

```bash
kubectl get nodes
kubectl get pods -A
```

## Infrastructure Components

### VPC Configuration
- CIDR: 10.0.0.0/16
- 3 Public subnets (for ALB)
- 3 Private subnets (for EKS nodes)
- 3 Database subnets (for RDS)
- NAT Gateway for private subnet internet access

### EKS Cluster
- Kubernetes version: 1.28
- Managed node groups with auto-scaling
- IRSA enabled for pod-level IAM permissions
- CoreDNS, kube-proxy, VPC CNI, EBS CSI driver

### RDS PostgreSQL
- Engine: PostgreSQL 15.4
- Instance class: db.t3.micro (configurable)
- Multi-AZ: Disabled (enable for production)
- Automated backups: 7 days retention
- Performance Insights enabled

### ECR Repositories
- user-service repository created by default
- Image scanning enabled
- Lifecycle policies to cleanup old images

## Adding New Services

To add a new service (e.g., product-service):

### 1. Add ECR Repository

Edit `ecr.tf`:

```hcl
resource "aws_ecr_repository" "product_service" {
  name                 = "product-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}
```

### 2. Add IAM Role (if needed)

Edit `rds.tf` or create a new service-specific file:

```hcl
module "product_service_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.cluster_name}-product-service"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:product-service"]
    }
  }

  tags = var.tags
}
```

### 3. Apply Changes

```bash
terraform plan
terraform apply
```

## Outputs

Key outputs available after deployment:

```bash
# Get cluster name
terraform output cluster_name

# Get ECR repository URL
terraform output ecr_repository_url_user_service

# Get RDS endpoint
terraform output db_instance_endpoint

# Get Jenkins credentials
terraform output -json jenkins_credentials_secret_arn | jq -r
```

## Jenkins Integration

### IAM Credentials

Jenkins IAM credentials are automatically created and stored in AWS Secrets Manager:

```bash
# Get Jenkins credentials ARN
terraform output jenkins_credentials_secret_arn

# Retrieve credentials
aws secretsmanager get-secret-value \
    --secret-id $(terraform output -raw jenkins_credentials_secret_arn) \
    --query SecretString \
    --output text | jq
```

### Configure Jenkins

1. Add AWS credentials in Jenkins:
    - Go to: Manage Jenkins → Credentials
    - Add AWS credentials using the access key from Secrets Manager
    - ID: `aws-credentials`

2. Add ECR registry URL:
    - Store ECR registry URL as credential
    - ID: `ecr-registry-url`

## Security Considerations

### For Production:

1. **Enable RDS Multi-AZ**:
   ```hcl
   multi_az = true
   ```

2. **Use AWS Secrets Manager** for database credentials instead of variables

3. **Enable deletion protection**:
   ```hcl
   deletion_protection = true
   ```

4. **Restrict cluster endpoint access**:
   ```hcl
   cluster_endpoint_public_access = false
   cluster_endpoint_private_access = true
   ```

5. **Enable encryption**:
    - Enable EBS encryption
    - Enable S3 encryption for backups
    - Use KMS for RDS encryption

6. **Network policies**: Implement Kubernetes network policies

7. **Pod Security Standards**: Enable PSS admission controller

## Cost Optimization

Current configuration costs approximately:
- EKS Cluster: ~$73/month
- Worker nodes (2x t3.medium): ~$60/month
- RDS (db.t3.micro): ~$15/month
- NAT Gateway: ~$32/month
- Load Balancer: ~$16/month

**Total: ~$196/month**

To reduce costs:
- Use spot instances for worker nodes
- Use single NAT Gateway (already default)
- Stop non-production environments when not in use

## Cleanup

To destroy all infrastructure:

```bash
# Delete all Kubernetes resources first
kubectl delete ingress --all -A
kubectl delete svc --all -A

# Destroy Terraform infrastructure
terraform destroy
```

**Warning**: This will permanently delete all resources including databases!

## Troubleshooting

### Cannot connect to cluster

```bash
aws eks update-kubeconfig --name <cluster-name> --region us-east-1
```

### Pods cannot pull images from ECR

Check IAM roles and ensure worker nodes have ECR pull permissions.

### RDS connection timeout

Verify security groups allow traffic from EKS nodes to RDS.

## Support

For issues or questions, please check:
- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

MIT