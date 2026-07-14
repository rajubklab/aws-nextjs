# GitHub Actions OIDC Role Setup

This guide explains how to set up AWS IAM role assumption for GitHub Actions using OpenID Connect (OIDC). This is more secure than using long-lived AWS credentials.

## Overview

Instead of storing AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY as GitHub secrets, we use:

- **OIDC Provider**: GitHub's identity provider
- **IAM Role**: AWS role that GitHub Actions can assume
- **Temporary Credentials**: Short-lived tokens issued by AWS

**Benefits:**

- ✅ No long-lived credentials to rotate
- ✅ Credentials are temporary and scoped to single workflow runs
- ✅ Full audit trail in AWS CloudTrail
- ✅ Follows AWS security best practices

---

## Setup Instructions

### Step 1: Get Your GitHub Repository Details

You'll need:

- GitHub Organization: `your-org` (or username for personal repos)
- GitHub Repository: `aws-nextjs`
- GitHub Repository ID: Get from GitHub API or Actions settings

```bash
# Get repo ID (replace YOUR_USERNAME)
curl -s https://api.github.com/repos/YOUR_USERNAME/aws-nextjs | jq '.id'
```

### Step 2: Create OIDC Provider in AWS

```bash
# Set your GitHub org/username
GITHUB_ORG="your-username"  # Change this to your GitHub username/org

# Create OIDC Provider
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
  --region us-east-1

echo "✅ OIDC Provider created (or already exists)"
```

### Step 3: Create IAM Role

```bash
# Set variables
GITHUB_ORG="your-username"
REPO_NAME="aws-nextjs"
ROLE_NAME="GitHubActionsECRDeployRole"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create trust policy
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${REPO_NAME}:*"
        }
      }
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-policy.json

echo "✅ IAM Role created: $ROLE_NAME"

# Save the Role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo "📌 Role ARN: $ROLE_ARN"
```

### Step 4: Attach IAM Policy to Role

```bash
ROLE_NAME="GitHubActionsECRDeployRole"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create policy document
cat > /tmp/policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:ListImages"
      ],
      "Resource": "arn:aws:ecr:*:AWS_ACCOUNT_ID:repository/aws-nextjs"
    },
    {
      "Sid": "EKSAccess",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSAuth",
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "arn:aws:iam::AWS_ACCOUNT_ID:role/eks-*"
    }
  ]
}
EOF

# Replace AWS_ACCOUNT_ID in policy
sed -i.bak "s/AWS_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" /tmp/policy.json

# Create and attach policy
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "GitHubActionsPolicy" \
  --policy-document file:///tmp/policy.json

echo "✅ Policy attached to role"
```

### Step 5: Add Role ARN to GitHub Secrets

```bash
ROLE_NAME="GitHubActionsECRDeployRole"

# Get Role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo "Role ARN: $ROLE_ARN"
```

In your GitHub repository:

1. Go to **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Create a secret named: `AWS_ROLE_ARN`
4. Set the value to your Role ARN from above
5. Click **Add secret**

**Example Role ARN:**

```
arn:aws:iam::123456789012:role/GitHubActionsECRDeployRole
```

---

## Verification

### Test 1: Verify OIDC Provider

```bash
aws iam list-open-id-connect-providers
# Should see: arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

### Test 2: Verify IAM Role

```bash
ROLE_NAME="GitHubActionsECRDeployRole"
aws iam get-role --role-name "$ROLE_NAME"
aws iam list-role-policies --role-name "$ROLE_NAME"
aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "GitHubActionsPolicy"
```

### Test 3: Run GitHub Actions Workflow

1. Push to main branch or trigger workflow manually
2. Check GitHub Actions tab for workflow run
3. Verify it uses the role to assume
4. Check AWS CloudTrail for AssumeRoleWithWebIdentity events

---

## Cleanup (if needed)

```bash
ROLE_NAME="GitHubActionsECRDeployRole"

# Delete inline policy
aws iam delete-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "GitHubActionsPolicy"

# Delete role
aws iam delete-role --role-name "$ROLE_NAME"

# Delete OIDC provider (if no longer needed)
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
```

---

## Automated Setup Script

```bash
#!/bin/bash
set -e

GITHUB_ORG="${1:-your-username}"
REPO_NAME="aws-nextjs"
ROLE_NAME="GitHubActionsECRDeployRole"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

echo "🔧 Setting up GitHub OIDC Role..."
echo "GitHub Org: $GITHUB_ORG"
echo "Repository: $REPO_NAME"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo ""

# Create OIDC Provider
echo "1️⃣ Creating OIDC Provider..."
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
  --region "$AWS_REGION" 2>/dev/null || echo "   (Provider may already exist)"

# Create trust policy
echo "2️⃣ Creating IAM Role..."
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${REPO_NAME}:*"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-policy.json 2>/dev/null || echo "   (Role may already exist)"

# Create policy document
echo "3️⃣ Attaching IAM Policy..."
cat > /tmp/policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": ["ecr:GetAuthorizationToken"],
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:DescribeImages",
        "ecr:ListImages"
      ],
      "Resource": "arn:aws:ecr:*:${AWS_ACCOUNT_ID}:repository/aws-nextjs"
    },
    {
      "Sid": "EKSAccess",
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    },
    {
      "Sid": "EKSAuth",
      "Effect": "Allow",
      "Action": ["sts:AssumeRole"],
      "Resource": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/eks-*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "GitHubActionsPolicy" \
  --policy-document file:///tmp/policy.json

# Get Role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📌 Next Step: Add this secret to GitHub"
echo "   Secret Name: AWS_ROLE_ARN"
echo "   Secret Value: $ROLE_ARN"
echo ""
echo "Go to: Settings → Secrets and variables → Actions → New repository secret"
```

Save the script and run:

```bash
chmod +x setup-oidc.sh
./setup-oidc.sh your-github-username
```

---

## Workflow Changes

Your workflow now uses:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ env.AWS_REGION }}
```

Instead of:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```

---

## Security Benefits

| Aspect          | Long-lived Keys  | OIDC Role          |
| --------------- | ---------------- | ------------------ |
| Credentials     | Permanent        | Temporary (1 hour) |
| Rotation        | Manual           | Automatic          |
| Scope           | All AWS services | Limited by policy  |
| Audit Trail     | Limited          | CloudTrail events  |
| Compromise Risk | High             | Low                |
| Key Management  | Complex          | Managed by AWS     |

---

## Troubleshooting

**Error: "InvalidParameterException: Duplicate oidc provider"**

- The OIDC provider already exists, skip creation

**Error: "EntityAlreadyExists: Role with name already exists"**

- The role already exists, verify trust policy and permissions

**Error: "AccessDenied" in workflow**

- Check IAM policy attached to role
- Verify role ARN in GitHub secret
- Check repository name and org in trust policy

**To debug workflow:**

```bash
# Check CloudTrail for AssumeRoleWithWebIdentity events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --max-items 5
```

---

## References

- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS IAM OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [Configure AWS Credentials Action](https://github.com/aws-actions/configure-aws-credentials)
