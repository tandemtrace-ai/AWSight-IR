#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${GREEN}[CHECK] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 is required but not installed."
    else
        log "$1 is installed"
    fi
}

# Check required commands
log "Checking required tools..."
check_command "aws"
check_command "jq"

# Check AWS credentials
log "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    error "AWS credentials are not configured or are invalid"
else
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    log "AWS credentials are valid for account: $AWS_ACCOUNT_ID"
    log "Using AWS user: $AWS_USER"
fi

# Check AWS region
log "Checking AWS region..."
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    error "AWS region is not configured"
else
    log "Using AWS region: $AWS_REGION"
fi

# Check required permissions
log "Checking AWS permissions..."

# Function to check IAM permissions
check_iam_permission() {
    local permission=$1
    local resource=$2
    if aws iam simulate-principal-policy \
        --policy-source-arn "$AWS_USER" \
        --action-names "$permission" \
        --resource-arns "$resource" \
        --query 'EvaluationResults[0].EvalDecision' \
        --output text | grep -q "allowed"; then
        log "Permission $permission is allowed"
    else
        warning "Permission $permission might not be allowed"
    fi
}

# Check CloudFormation permissions
check_iam_permission "cloudformation:CreateStack" "arn:aws:cloudformation:${AWS_REGION}:${AWS_ACCOUNT_ID}:stack/*"
check_iam_permission "cloudformation:DeleteStack" "arn:aws:cloudformation:${AWS_REGION}:${AWS_ACCOUNT_ID}:stack/*"

# Check S3 permissions
check_iam_permission "s3:CreateBucket" "arn:aws:s3:::*"
check_iam_permission "s3:PutObject" "arn:aws:s3:::*"
check_iam_permission "s3:DeleteObject" "arn:aws:s3:::*"

# Check Lambda permissions
check_iam_permission "lambda:CreateFunction" "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:*"
check_iam_permission "lambda:InvokeFunction" "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:*"

# Check for required files
log "Checking for required files..."
required_files=("ir-infrastructure.yaml" "ir-collector.zip")
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        log "Found required file: $file"
    else
        error "Required file not found: $file"
    fi
done

# Check available AWS resources
log "Checking AWS resource limits..."

# Check Lambda limits
LAMBDA_LIMIT=$(aws lambda get-account-settings --query 'AccountLimit.ConcurrentExecutions' --output text)
log "Lambda concurrent execution limit: $LAMBDA_LIMIT"

# Check CloudFormation stack limit
CF_STACKS=$(aws cloudformation describe-account-limits --query 'AccountLimits[?Name==`StackLimit`].Value' --output text)
log "CloudFormation stack limit: $CF_STACKS"

# Final status
log "Prerequisites check completed successfully!"
log "You can proceed with running the deployment script."