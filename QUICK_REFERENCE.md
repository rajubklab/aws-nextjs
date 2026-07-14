# Quick Reference Guide

## 📋 Files Created

### Docker

- **Dockerfile** - Multistage build optimized for minimal size (~150-200MB)
- **.dockerignore** - Excludes unnecessary files from build context

### GitHub Actions

- **.github/workflows/ecr-push.yml** - CI/CD pipeline to build and push to ECR

### Kubernetes Manifests

- **k8s/deployment.yaml** - Pod deployment with 3 replicas, health checks, security
- **k8s/service.yaml** - ClusterIP service for internal networking
- **k8s/ingress.yaml** - ALB ingress for app.rajubk.online
- **k8s/hpa.yaml** - Horizontal Pod Autoscaler (3-10 replicas)

### Scripts

- **scripts/setup-deployment.sh** - One-time setup automation
- **scripts/deploy.sh** - Quick deployment to EKS
- **scripts/manage.sh** - Deployment management utilities

### Documentation

- **DEPLOYMENT.md** - Complete deployment guide
- **app/api/health/route.ts** - Health check endpoint

---

## 🚀 Quick Start (5 steps)

### Step 1: Prepare AWS

```bash
# Create ECR repo
aws ecr create-repository --repository-name aws-nextjs --region us-east-1

# Get your Account ID
aws sts get-caller-identity --query Account --output text
```

### Step 2: Set Up GitHub OIDC Role (Recommended)

```bash
# Read the setup guide
cat GITHUB_OIDC_SETUP.md

# Or run automated setup
chmod +x scripts/setup-oidc.sh
./scripts/setup-oidc.sh your-github-username
```

Add this secret to GitHub repo → Settings → Secrets:

- `AWS_ROLE_ARN` (from setup output)

**Why OIDC?** No long-lived credentials, automatic rotation, full audit trail

### Step 3: Update Config Files

**k8s/deployment.yaml** - Replace ECR URL:

```yaml
image: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/aws-nextjs:latest
```

**k8s/ingress.yaml** - Replace ACM certificate ARN:

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```

### Step 4: Deploy to EKS

```bash
./scripts/deploy.sh default
# or manually:
kubectl apply -f k8s/
```

### Step 5: Configure Route 53

```bash
# Get ALB DNS
kubectl get ingress nextjs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Create CNAME in Route 53
# Name: app.rajubk.online
# Type: CNAME
# Value: <ALB_DNS_NAME>
```

---

## 📦 Image Size Optimization

The multistage Dockerfile achieves:

- **Builder stage**: Node.js 20 Alpine + dependencies (~500MB)
- **Runtime stage**: Only built app files (~150-200MB)
- **Final image**: ~150-250MB (very efficient for Next.js!)

---

## 🔒 Security Features

✅ Non-root user (UID 1001)  
✅ Read-only root filesystem  
✅ No elevated privileges  
✅ Pod security context  
✅ Resource limits enforced  
✅ Health checks configured

---

## 📊 Kubernetes Features

✅ **3 replicas** by default  
✅ **Rolling updates** - zero downtime  
✅ **Auto-scaling** - CPU/memory based  
✅ **Pod Disruption Budget** - minimum 2 available  
✅ **Pod Anti-Affinity** - spread across nodes  
✅ **Liveness & Readiness Probes** - health monitoring

---

## 🔄 CI/CD Pipeline

**Triggers**: Push to main branch or manual workflow_dispatch

**Steps**:

1. Checkout code
2. Configure AWS credentials
3. Login to ECR
4. Build Docker image
5. Push to ECR (with git SHA and `latest` tags)
6. Update EKS deployment

---

## 📝 Useful Commands

```bash
# Check deployment status
kubectl get deployments,services,ingress

# View logs
kubectl logs -f deployment/nextjs-app

# Scale replicas
kubectl scale deployment/nextjs-app --replicas=5

# Restart deployment
kubectl rollout restart deployment/nextjs-app

# Check HPA status
kubectl get hpa -w

# Port forward for local testing
kubectl port-forward svc/nextjs-app 3000:80

# Delete everything
kubectl delete -f k8s/
```

---

## 🔧 Customization

### Change Replicas

Edit `k8s/deployment.yaml` or `k8s/hpa.yaml`

### Adjust Resources

```yaml
resources:
  requests:
    cpu: 100m # Change as needed
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Add Environment Variables

In `k8s/deployment.yaml`:

```yaml
env:
  - name: MY_ENV_VAR
    value: "my-value"
```

### Use Secrets

```bash
kubectl create secret generic app-secrets --from-literal=API_KEY=xxx
```

Then reference in deployment:

```yaml
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: API_KEY
```

---

## ⚠️ Important Notes

1. **AWS Account ID**: Replace `123456789012` in config files
2. **Region**: Update if not using `us-east-1`
3. **Cluster Name**: Update EKS cluster name in workflow and scripts
4. **SSL Certificate**: Must be in ACM for the ingress to work
5. **Route 53**: CNAME record must point to ALB DNS

---

## 📚 Related Documentation

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Full deployment guide
- [Dockerfile](./Dockerfile) - Docker image details
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ALB Ingress Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

---

## 💡 Cost Optimization Tips

- **Reduce replicas**: Change `replicas: 3` to lower number
- **Downsize requests**: Reduce CPU/memory requests
- **Use Spot instances**: Save up to 70% with AWS Spot
- **Image size**: Already optimized at ~150-200MB
- **Delete unused resources**: Clean up unneeded ECR repos/ALBs

---

## 🆘 Troubleshooting

**ALB not provisioning?**

```bash
# Check ingress status
kubectl describe ingress nextjs-app
# Check ALB controller logs
kubectl logs -n kube-system -f deployment/aws-load-balancer-controller
```

**Pods not starting?**

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**Image pull errors?**

```bash
# Check ECR credentials
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

**Route 53 not resolving?**

```bash
# Verify CNAME points to ALB
dig app.rajubk.online
# Get current ALB DNS
kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

---

**Happy Deploying! 🎉**
