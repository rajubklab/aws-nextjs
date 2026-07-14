# Deployment Checklist

## Pre-Deployment ✅

### AWS Setup

- [ ] Create ECR repository: `aws-nextjs`
- [ ] Enable AWS API credentials (Access Key + Secret)
- [ ] Create/import SSL certificate in ACM for `*.rajubk.online`
- [ ] Verify Route 53 hosted zone: `rajubk.online`
- [ ] EKS cluster created and running
- [ ] kubectl configured and connected to EKS cluster

### GitHub Setup

- [ ] Repository created and pushed
- [ ] GitHub OIDC Role setup (see GITHUB_OIDC_SETUP.md):
  - [ ] OIDC provider created in AWS IAM
  - [ ] IAM role created with trust policy
  - [ ] IAM policy attached to role
  - [ ] `AWS_ROLE_ARN` secret added to GitHub
- [ ] `.github/workflows/ecr-push.yml` workflow visible in GitHub

## Configuration ✅

### Update Configuration Files

- [ ] **k8s/deployment.yaml**
  - [ ] Replace ECR URL with actual: `YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/aws-nextjs:latest`
  - [ ] Verify resource requests/limits match your needs
- [ ] **k8s/ingress.yaml**
  - [ ] Replace ACM certificate ARN
  - [ ] Verify hostname: `app.rajubk.online`
- [ ] **.github/workflows/ecr-push.yml**
  - [ ] AWS_REGION: us-east-1 (or your region)
  - [ ] ECR_REPOSITORY: aws-nextjs
  - [ ] EKS cluster name: aws-nextjs-cluster

- [ ] **.env.deployment** (for reference)
  - [ ] Update with your values

## Pre-Flight Checks ✅

```bash
# Run these commands before deployment:

# 1. Verify Docker image builds locally
docker build -t aws-nextjs:test .

# 2. Check file sizes
du -sh . # Project size
docker images # After building

# 3. Verify Kubernetes manifests syntax
kubectl apply -f k8s/ --dry-run=client

# 4. Check EKS cluster connectivity
kubectl cluster-info
kubectl get nodes
```

- [ ] Docker image builds successfully
- [ ] Kubernetes manifests are valid
- [ ] Can connect to EKS cluster
- [ ] ALB Ingress Controller installed in kube-system namespace

## Deployment 🚀

### Initial Deployment

```bash
# Option 1: Auto-setup (if using setup-deployment.sh)
./scripts/setup-deployment.sh

# Option 2: Manual deployment
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
```

- [ ] Deployment manifests applied
- [ ] Pods are running (check: `kubectl get pods`)
- [ ] Service created (check: `kubectl get svc`)
- [ ] Ingress created (check: `kubectl get ingress`)
- [ ] HPA created (check: `kubectl get hpa`)

### Verify Deployment

```bash
# Check rollout status
kubectl rollout status deployment/nextjs-app

# Check pod logs for errors
kubectl logs -f deployment/nextjs-app

# Check ingress status
kubectl describe ingress nextjs-app
```

- [ ] All pods in Running state
- [ ] No error logs in pods
- [ ] Ingress has ALB DNS assigned
- [ ] ALB endpoints healthy

### DNS Configuration

```bash
# Get ALB DNS name
ALB_DNS=$(kubectl get ingress nextjs-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ALB_DNS
```

In AWS Route 53:

- [ ] CNAME record created: `app.rajubk.online` → `<ALB_DNS_NAME>`
- [ ] OR A record with alias pointing to ALB
- [ ] DNS propagated (wait 5-10 minutes)
- [ ] Test DNS: `nslookup app.rajubk.online`

## CI/CD Pipeline 🔄

### First Deployment via GitHub Actions

- [ ] Trigger workflow: Push to main branch or manual trigger
- [ ] Watch workflow execution in GitHub Actions
- [ ] Verify image pushed to ECR: `aws ecr describe-images --repository-name aws-nextjs`
- [ ] Check new image deployed: `kubectl get deployment nextjs-app -o yaml | grep image`

### Verify CI/CD Updates

- [ ] Make a code change
- [ ] Push to main branch
- [ ] Workflow triggers automatically
- [ ] New image pushed to ECR
- [ ] Pods rolling update (no downtime)

## Testing 🧪

### HTTP Access

```bash
# Direct pod access
kubectl port-forward svc/nextjs-app 3000:80

# Then visit: http://localhost:3000
```

- [ ] Can access application via port-forward
- [ ] Health check endpoint works: `/api/health`
- [ ] App loads correctly

### HTTPS/DNS Access

- [ ] Access via domain: `https://app.rajubk.online`
- [ ] SSL certificate valid (no warnings)
- [ ] Redirects HTTP to HTTPS

### Performance & Metrics

```bash
kubectl top nodes
kubectl top pods
```

- [ ] CPU usage reasonable
- [ ] Memory usage within limits
- [ ] Ingress processing traffic
- [ ] HPA responding to load (if applicable)

## Post-Deployment ✅

### Monitoring

- [ ] Set up CloudWatch logs for ALB
- [ ] Set up CloudWatch alarms for:
  - [ ] Pod CPU > 70%
  - [ ] Pod memory > 80%
  - [ ] Pod restarts > 0
  - [ ] ALB unhealthy hosts

### Backup & Documentation

- [ ] Save current kube config
- [ ] Document any custom environment variables
- [ ] Document any manual configurations
- [ ] Keep track of ECR image tags for rollback

### Optimization

- [ ] Review pod resource usage after 1-2 days
- [ ] Adjust resource requests/limits if needed
- [ ] Check image size: `docker image ls`
- [ ] Review CloudWatch logs for errors

## Maintenance 🔧

### Regular Tasks

- [ ] Monitor pod logs weekly
- [ ] Review HPA scaling decisions
- [ ] Check for security updates
- [ ] Clean up old ECR images

### Scaling

- [ ] Adjust `replicas` for increased load
- [ ] Modify HPA min/max replicas if needed
- [ ] Update resource requests/limits if needed

### Troubleshooting

- [ ] Bookmark [DEPLOYMENT.md](./DEPLOYMENT.md)
- [ ] Bookmark [QUICK_REFERENCE.md](./QUICK_REFERENCE.md)
- [ ] Save ALB DNS name
- [ ] Keep AWS console dashboard handy

## Emergency Procedures 🚨

### Rollback to Previous Version

```bash
kubectl rollout undo deployment/nextjs-app
kubectl rollout status deployment/nextjs-app
```

- [ ] Understand how to rollback
- [ ] Test rollback procedure (at least once)
- [ ] Know how to check rollout history

### Scale Down in Emergency

```bash
kubectl scale deployment/nextjs-app --replicas=1
```

- [ ] Know how to quickly scale down
- [ ] Know how to delete deployment if needed

---

## Support Resources

- **Full Guide**: See [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Quick Ref**: See [QUICK_REFERENCE.md](./QUICK_REFERENCE.md)
- **GitHub Issues**: Check GitHub Actions logs for errors
- **AWS Support**: CloudWatch → Logs for application errors

---

**Status**: Ready for deployment! ✨
