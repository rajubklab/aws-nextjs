# Deployment Setup Guide

This guide walks you through deploying your Next.js app to AWS EKS with a CI/CD pipeline using GitHub Actions.

## Prerequisites

- AWS Account with appropriate permissions
- EKS Cluster already created
- Route 53 hosted zone for rajubk.online
- AWS CLI configured
- kubectl configured to access your EKS cluster
- ECR repository created

## Step 1: Set Up AWS ECR Repository

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name aws-nextjs \
  --region us-east-1

# Get the repository URI (you'll need this)
aws ecr describe-repositories --repository-names aws-nextjs --region us-east-1
```

## Step 2: Set Up GitHub OIDC Role (Recommended - More Secure)

Instead of long-lived AWS credentials, use IAM role assumption via OIDC:

```bash
# Follow the complete setup guide:
cat GITHUB_OIDC_SETUP.md

# Or run the automated script:
chmod +x scripts/setup-oidc.sh
./scripts/setup-oidc.sh your-github-username
```

**After setup:**

1. Add secret to GitHub: `AWS_ROLE_ARN` (from OIDC setup output)
2. Skip to Step 3

**Benefits:**

- ✅ No long-lived credentials
- ✅ Temporary credentials (1 hour)
- ✅ Automatic rotation
- ✅ Full CloudTrail audit trail

See [GITHUB_OIDC_SETUP.md](./GITHUB_OIDC_SETUP.md) for detailed instructions.

## Step 3: Update Configuration Files

### Update `.github/workflows/ecr-push.yml`

Replace the following placeholders:

- `AWS_REGION`: Your AWS region (default: us-east-1)
- `ECR_REPOSITORY`: Your ECR repo name (default: aws-nextjs)
- `aws-nextjs-cluster`: Your EKS cluster name

### Update `k8s/deployment.yaml`

Replace ECR URL:

```yaml
image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/aws-nextjs:latest
```

Get your account ID:

```bash
aws sts get-caller-identity --query Account --output text
```

### Update `k8s/ingress.yaml`

1. **ACM Certificate ARN**: Replace with your SSL certificate

```bash
# Create or import SSL certificate in ACM
aws acm request-certificate \
  --domain-name app.rajubk.online \
  --domain-name rajubk.online \
  --region us-east-1
```

2. The ingress already points to `app.rajubk.online`

## Step 4: Install AWS ALB Ingress Controller

```bash
# Add the EKS repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install ALB Ingress Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=aws-nextjs-cluster \
  --set serviceAccount.create=true
```

## Step 5: Configure Route 53

1. Go to AWS Route 53 console
2. Create a CNAME record:
   - **Name**: app.rajubk.online
   - **Type**: CNAME
   - **Value**: ALB DNS name (get from AWS console or: `kubectl get ingress -n default -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'`)

   Or use an A record with an alias pointing to the ALB.

## Step 6: Deploy to EKS

```bash
# Deploy the manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# Verify deployment
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get hpa
```

## Step 7: Trigger the GitHub Action

```bash
# Push to main branch or manually trigger the workflow
git push origin main
```

The workflow will:

1. Build the Docker image
2. Push to ECR
3. Update the EKS deployment with the new image

## Monitoring and Troubleshooting

### Check pod status

```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

### Check ingress status

```bash
kubectl get ingress -n default -o wide
kubectl describe ingress nextjs-app -n default
```

### Check ALB

```bash
# Get ALB DNS name
kubectl get ingress nextjs-app -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### View metrics

```bash
kubectl top nodes
kubectl top pods -n default
```

## Dockerfile Optimization

The Dockerfile uses a **2-stage build** for minimal image size:

1. **Builder stage**: Installs dependencies and builds the app (~500MB)
2. **Runtime stage**: Copies only built artifacts, uses Alpine Linux (~150-200MB)

The final image is typically **150-250MB** depending on your dependencies.

## Features

✅ **Multistage Build** - Minimal image size  
✅ **Non-root User** - Security best practice  
✅ **Health Checks** - Kubernetes probes included  
✅ **Resource Limits** - CPU and memory constraints  
✅ **Auto-scaling** - HPA configured (3-10 replicas)  
✅ **SSL/TLS** - Configured via ACM certificate  
✅ **High Availability** - Rolling updates, pod disruption budgets  
✅ **CI/CD Pipeline** - Automated builds and deployments

## Environment Variables

Add any environment variables to the Deployment spec under `env`:

```yaml
env:
  - name: MY_VAR
    value: "my-value"
```

For secrets, use Kubernetes Secrets:

```bash
kubectl create secret generic app-secrets \
  --from-literal=DATABASE_URL=your_db_url
```

Then reference in deployment:

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: DATABASE_URL
```

## Cost Optimization Tips

1. **Reduce replicas** - Change `replicas: 3` to lower number
2. **Smaller instances** - Use smaller EC2 nodes in your EKS cluster
3. **Spot instances** - Use AWS Spot Instances for cost savings
4. **Image size** - Current build is ~150-200MB (optimized)
5. **Resource requests** - Adjust based on actual usage

## Rollback

```bash
# View rollout history
kubectl rollout history deployment/nextjs-app

# Rollback to previous version
kubectl rollout undo deployment/nextjs-app
```

## Delete Resources

```bash
# Remove from EKS
kubectl delete -f k8s/

# Delete ECR repository
aws ecr delete-repository --repository-name aws-nextjs --force

# Delete ALB (automatically deleted with ingress)
```
