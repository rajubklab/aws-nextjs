#!/bin/bash

# Deploy script for Next.js app to EKS

set -e

NAMESPACE=${1:-default}
KUBECONFIG_CONTEXT=${2:-}

echo "🚀 Deploying Next.js app to EKS..."
echo "Namespace: $NAMESPACE"

# Set context if provided
if [ -n "$KUBECONFIG_CONTEXT" ]; then
    kubectl config use-context "$KUBECONFIG_CONTEXT"
fi

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests
echo "📦 Applying Kubernetes manifests..."
kubectl apply -f k8s/deployment.yaml -n "$NAMESPACE"
kubectl apply -f k8s/service.yaml -n "$NAMESPACE"
kubectl apply -f k8s/ingress.yaml -n "$NAMESPACE"
kubectl apply -f k8s/hpa.yaml -n "$NAMESPACE"

echo "✅ Manifests applied successfully!"

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/nextjs-app -n "$NAMESPACE" --timeout=5m

# Get status
echo ""
echo "📊 Deployment Status:"
echo ""
kubectl get deployments -n "$NAMESPACE"
echo ""
kubectl get services -n "$NAMESPACE"
echo ""
kubectl get ingress -n "$NAMESPACE"
echo ""
kubectl get pods -n "$NAMESPACE"

# Get ALB DNS
echo ""
echo "🔗 ALB Information:"
ALB_DNS=$(kubectl get ingress nextjs-app -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
echo "DNS Name: $ALB_DNS"
echo ""
echo "✨ Application is being deployed to EKS!"
echo "Please wait a few minutes for the ALB to fully initialize."
