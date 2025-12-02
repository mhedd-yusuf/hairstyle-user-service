#!/bin/bash

# Script to debug environment variables in Kubernetes pods
# This helps verify that ConfigMap and Secret values are being injected correctly

echo "========================================"
echo "Debugging Environment Variables in Pods"
echo "========================================"
echo ""

# Configuration
NAMESPACE="default"
APP_NAME="hairstyle-user-service"

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --region eu-west-2 --name springboot-eks-cluster
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo "❌ No pods found for app: ${APP_NAME}"
    exit 1
fi

echo "Found pod: ${POD_NAME}"
echo ""

# Check ConfigMap
echo "========== ConfigMap =========="
echo "Checking hairstyle-user-service-config..."
kubectl get configmap hairstyle-user-service-config -n ${NAMESPACE} -o yaml | grep SPRING_DATASOURCE_URL
echo ""

# Check Secret (decoded)
echo "========== Secret =========="
echo "Database Username:"
kubectl get secret hairstyle-user-service-secret -n ${NAMESPACE} -o jsonpath='{.data.db-username}' | base64 -d
echo ""
echo "Database Password:"
kubectl get secret hairstyle-user-service-secret -n ${NAMESPACE} -o jsonpath='{.data.db-password}' | base64 -d
echo ""
echo ""

# Check environment variables inside the pod
echo "========== Environment Variables in Pod =========="
echo "Checking environment variables inside ${POD_NAME}..."
echo ""

kubectl exec -n ${NAMESPACE} ${POD_NAME} -- env | grep -E "SPRING_DATASOURCE|JAVA_OPTS" | sort
echo ""

# Specifically check the datasource URL
echo "========== Database URL Being Used =========="
DATASOURCE_URL=$(kubectl exec -n ${NAMESPACE} ${POD_NAME} -- env | grep SPRING_DATASOURCE_URL | cut -d'=' -f2-)
echo "SPRING_DATASOURCE_URL=${DATASOURCE_URL}"
echo ""

if [[ $DATASOURCE_URL == *"localhost"* ]]; then
    echo "❌ WARNING: Application is using localhost! ConfigMap not being injected properly!"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Verify ConfigMap exists: kubectl get configmap hairstyle-user-service-config -n ${NAMESPACE}"
    echo "2. Verify deployment references correct ConfigMap: kubectl get deployment ${APP_NAME} -n ${NAMESPACE} -o yaml | grep configMapRef"
    echo "3. Restart deployment: kubectl rollout restart deployment/${APP_NAME} -n ${NAMESPACE}"
elif [[ $DATASOURCE_URL == *"rds.amazonaws.com"* ]]; then
    echo "✅ SUCCESS: Application is using RDS endpoint!"
else
    echo "⚠️  WARNING: Unexpected datasource URL"
fi

echo ""

# Check pod logs for connection attempts
echo "========== Recent Application Logs =========="
echo "Last 20 lines of application logs..."
kubectl logs -n ${NAMESPACE} ${POD_NAME} --tail=20
echo ""

# Check pod description for any issues
echo "========== Pod Events =========="
kubectl describe pod -n ${NAMESPACE} ${POD_NAME} | grep -A 10 "Events:"
echo ""

# Summary
echo "========================================"
echo "Debug Summary"
echo "========================================"
echo "Pod Name: ${POD_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "ConfigMap: hairstyle-user-service-config"
echo "Secret: hairstyle-user-service-secret"
echo ""
echo "To view full logs:"
echo "  kubectl logs -f -n ${NAMESPACE} ${POD_NAME}"
echo ""
echo "To exec into pod:"
echo "  kubectl exec -it -n ${NAMESPACE} ${POD_NAME} -- /bin/sh"
echo ""