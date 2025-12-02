#!/bin/bash

# Force Clean Deployment Script
# This script completely removes the existing deployment and redeploys fresh

set -e

# Configuration
NAMESPACE="default"
APP_NAME="hairstyle-user-service"
AWS_REGION="eu-west-2"
EKS_CLUSTER="springboot-eks-cluster"

echo "========================================"
echo "Force Clean Deployment"
echo "========================================"
echo ""

# Configure kubectl
echo "🔧 Configuring kubectl..."
aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
echo "✓ kubectl configured"
echo ""

# Step 1: Delete existing resources
echo "🗑️  Step 1: Deleting existing resources..."
kubectl delete deployment ${APP_NAME} -n ${NAMESPACE} --ignore-not-found
kubectl delete svc ${APP_NAME} -n ${NAMESPACE} --ignore-not-found
echo "✓ Old resources deleted"
echo ""

# Step 2: Update ConfigMap and Secret
echo "⚙️  Step 2: Updating ConfigMap and Secret..."
kubectl apply -f k8s/configmap.yaml -n ${NAMESPACE}
kubectl apply -f k8s/secret.yaml -n ${NAMESPACE}
echo "✓ ConfigMap and Secret updated"
echo ""

# Step 3: Deploy fresh
echo "🚀 Step 3: Deploying fresh..."
kubectl apply -f k8s/deployment.yaml -n ${NAMESPACE}
kubectl apply -f k8s/service.yaml -n ${NAMESPACE}
echo "✓ Deployment and Service created"
echo ""

# Step 4: Wait for rollout
echo "⏳ Step 4: Waiting for rollout to complete..."
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=10m
echo "✓ Rollout complete"
echo ""

# Step 5: Verify deployment
echo "✅ Step 5: Verifying deployment..."
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}
echo ""
kubectl get svc -n ${NAMESPACE} -l app=${APP_NAME}
echo ""

# Step 6: Check environment variables
echo "🔍 Step 6: Checking environment variables..."
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} -o jsonpath='{.items[0].metadata.name}')

if [ -n "$POD_NAME" ]; then
    echo "Pod: ${POD_NAME}"
    echo ""
    echo "Database URL:"
    kubectl exec -n ${NAMESPACE} ${POD_NAME} -- env | grep SPRING_DATASOURCE_URL || echo "Not found"
    echo ""
    echo "Last 30 lines of logs:"
    kubectl logs -n ${NAMESPACE} ${POD_NAME} --tail=30
fi

echo ""
echo "========================================"
echo "✅ Clean Deployment Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Check application health: curl http://LOAD-BALANCER-URL/actuator/health"
echo "2. View logs: kubectl logs -f -n ${NAMESPACE} ${POD_NAME}"
echo "3. Get LoadBalancer URL: kubectl get svc ${APP_NAME} -n ${NAMESPACE}"
echo ""