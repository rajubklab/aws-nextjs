#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== AWS Next.js EKS Deployment Setup ===${NC}\n"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI found${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Helm found${NC}"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account ID: $ACCOUNT_ID${NC}\n"

# Prompt for configuration
read -p "Enter AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "Enter EKS cluster name (default: aws-nextjs-cluster): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-aws-nextjs-cluster}

read -p "Enter ECR repository name (default: aws-nextjs): " ECR_REPO
ECR_REPO=${ECR_REPO:-aws-nextjs}

read -p "Enter your domain (default: rajubk.online): " DOMAIN
DOMAIN=${DOMAIN:-rajubk.online}

read -p "Enter app subdomain (default: app): " SUBDOMAIN
SUBDOMAIN=${SUBDOMAIN:-app}

APP_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

echo -e "\n${YELLOW}Configuration:${NC}"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Account ID: $ACCOUNT_ID"
echo "  EKS Cluster: $CLUSTER_NAME"
echo "  ECR Repository: $ECR_REPO"
echo "  App Domain: $APP_DOMAIN\n"

# Create ECR repository
echo -e "${YELLOW}Creating ECR repository...${NC}"
aws ecr create-repository \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" 2>/dev/null || echo -e "${YELLOW}Repository may already exist${NC}"
echo -e "${GREEN}✓ ECR repository ready${NC}\n"

# Update kubeconfig
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"
echo -e "${GREEN}✓ Kubeconfig updated${NC}\n"

# Install ALB Ingress Controller
echo -e "${YELLOW}Installing AWS ALB Ingress Controller...${NC}"
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller 2>/dev/null || echo -e "${YELLOW}ALB controller may already be installed${NC}"
echo -e "${GREEN}✓ ALB Ingress Controller installed/updated${NC}\n"

# Update configuration files
echo -e "${YELLOW}Updating configuration files...${NC}"

# Update deployment.yaml
ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest"
sed -i.bak "s|123456789012.dkr.ecr.us-east-1.amazonaws.com/aws-nextjs:latest|$ECR_URI|g" k8s/deployment.yaml
echo -e "${GREEN}✓ Updated deployment.yaml${NC}"

# Update ingress.yaml
sed -i.bak "s|app.rajubk.online|$APP_DOMAIN|g" k8s/ingress.yaml
echo -e "${GREEN}✓ Updated ingress.yaml${NC}"

# Update GitHub workflow
sed -i.bak "s|us-east-1|$AWS_REGION|g" .github/workflows/ecr-push.yml
sed -i.bak "s|aws-nextjs|$ECR_REPO|g" .github/workflows/ecr-push.yml
sed -i.bak "s|aws-nextjs-cluster|$CLUSTER_NAME|g" .github/workflows/ecr-push.yml
echo -e "${GREEN}✓ Updated GitHub Actions workflow${NC}\n"

# Cleanup backup files
rm -f k8s/*.bak .github/workflows/*.bak

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to GitHub secrets"
echo "2. Run: kubectl apply -f k8s/ (to deploy to EKS)"
echo "3. Get ALB DNS: kubectl get ingress -n default -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
echo "4. Create Route 53 CNAME record:"
echo "   - Name: $APP_DOMAIN"
echo "   - Type: CNAME"
echo "   - Value: <ALB_DNS_NAME>"
echo -e "\n${GREEN}Setup complete!${NC}"
