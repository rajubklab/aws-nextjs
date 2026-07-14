#!/bin/bash

# Utility script to manage the deployed Next.js app on EKS

NAMESPACE=${1:-default}
COMMAND=${2:-status}

case $COMMAND in
  status)
    echo "📊 Deployment Status for namespace: $NAMESPACE"
    echo ""
    echo "Deployments:"
    kubectl get deployments -n "$NAMESPACE"
    echo ""
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo ""
    echo "Services:"
    kubectl get services -n "$NAMESPACE"
    echo ""
    echo "Ingress:"
    kubectl get ingress -n "$NAMESPACE" -o wide
    echo ""
    echo "HPA:"
    kubectl get hpa -n "$NAMESPACE"
    ;;
  
  logs)
    POD=$(kubectl get pods -n "$NAMESPACE" -l app=nextjs-app -o jsonpath='{.items[0].metadata.name}')
    if [ -z "$POD" ]; then
      echo "❌ No pods found with app=nextjs-app label"
      exit 1
    fi
    echo "📋 Logs from pod: $POD"
    kubectl logs -f "$POD" -n "$NAMESPACE"
    ;;
  
  scale)
    REPLICAS=$3
    if [ -z "$REPLICAS" ]; then
      echo "Usage: ./manage.sh <namespace> scale <number>"
      exit 1
    fi
    echo "⚙️  Scaling deployment to $REPLICAS replicas..."
    kubectl scale deployment/nextjs-app --replicas="$REPLICAS" -n "$NAMESPACE"
    echo "✅ Scaled successfully"
    ;;
  
  restart)
    echo "🔄 Restarting deployment..."
    kubectl rollout restart deployment/nextjs-app -n "$NAMESPACE"
    kubectl rollout status deployment/nextjs-app -n "$NAMESPACE" --timeout=5m
    echo "✅ Restarted successfully"
    ;;
  
  rollback)
    echo "⏮️  Rolling back to previous version..."
    kubectl rollout undo deployment/nextjs-app -n "$NAMESPACE"
    kubectl rollout status deployment/nextjs-app -n "$NAMESPACE" --timeout=5m
    echo "✅ Rolled back successfully"
    ;;
  
  delete)
    echo "🗑️  Deleting deployment..."
    kubectl delete deployment,service,ingress -l app=nextjs-app -n "$NAMESPACE"
    echo "✅ Deleted successfully"
    ;;
  
  *)
    echo "Usage: ./manage.sh <namespace> <command>"
    echo ""
    echo "Commands:"
    echo "  status                - Show deployment status"
    echo "  logs                  - Show pod logs (streaming)"
    echo "  scale <replicas>      - Scale deployment to N replicas"
    echo "  restart               - Restart the deployment"
    echo "  rollback              - Rollback to previous version"
    echo "  delete                - Delete the deployment"
    ;;
esac
