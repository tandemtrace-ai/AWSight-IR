#!/bin/bash
# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME_PREFIX="ir-cmdb"
ENVIRONMENT="prod"
RETENTION_DAYS="90"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
STACK_NAME="${STACK_NAME_PREFIX}-${TIMESTAMP}"
LOG_FILE="deployment_${TIMESTAMP}.log"

# Cache AWS credentials and configuration
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=$(aws configure get region)
export S3_BUCKET="ir-cmdb-deployment-${AWS_ACCOUNT_ID}"
export S3_KEY="lambda/ir-collector.zip"

# Helper functions
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}${message}${NC}" >&2
    echo "$message" >> "$LOG_FILE"
    exit 1
}

warning() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "$message" >> "$LOG_FILE"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --stack-name)
                STACK_NAME="$2"
                log "Stack name set to: $STACK_NAME"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                log "Environment set to: $ENVIRONMENT"
                shift 2
                ;;
            --retention-days)
                RETENTION_DAYS="$2"
                log "Retention days set to: $RETENTION_DAYS"
                shift 2
                ;;
            --update)
                UPDATE_STACK=true
                log "Update stack mode enabled"
                shift
                ;;
            *)
                error "Unknown parameter: $1"
                ;;
        esac
    done
}

# Function to ensure S3 bucket exists
ensure_s3_bucket() {
    if ! aws s3api head-bucket --bucket "${S3_BUCKET}" 2>/dev/null; then
        log "Creating S3 bucket ${S3_BUCKET}"
        aws s3api create-bucket \
            --bucket "${S3_BUCKET}" \
            --region ${AWS_REGION} \
            --create-bucket-configuration LocationConstraint=${AWS_REGION}

        aws s3api wait bucket-exists --bucket "${S3_BUCKET}"
        
        aws s3api put-bucket-versioning \
            --bucket "${S3_BUCKET}" \
            --versioning-configuration Status=Enabled
        
        sleep 2
        log "S3 bucket created and versioning enabled"
    else
        log "S3 bucket ${S3_BUCKET} already exists"
    fi
}

# Function to upload Lambda code
upload_lambda() {
    log "Uploading Lambda code to S3"
    aws s3 cp ir-collector.zip "s3://${S3_BUCKET}/${S3_KEY}" --only-show-errors || \
        error "Failed to upload Lambda code"
    log "Lambda code uploaded successfully"
}

# Check if stack exists
stack_exists() {
    aws cloudformation describe-stacks --stack-name "$1" >/dev/null 2>&1
}

# Function to wait for stack operation completion
wait_for_stack() {
    local operation=$1
    local start_time=$(date +%s)
    local timeout=1800  # 30 minutes timeout
    
    log "Waiting for stack $STACK_NAME ${operation} to complete..."
    while true; do
        if (( $(date +%s) - start_time > timeout )); then
            error "Stack operation timed out after 30 minutes"
        fi

        local STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus' --output text)
        case $STATUS in
            CREATE_COMPLETE|UPDATE_COMPLETE)
                log "Stack $STACK_NAME ${operation} completed successfully!"
                return 0
                ;;
            *ROLLBACK_COMPLETE|*FAILED)
                error "Stack ${operation} failed with status: $STATUS"
                ;;
            *)
                sleep 5
                ;;
        esac
    done
}

# Deploy or update CloudFormation stack
deploy_stack() {
    local cmd="create-stack"
    local operation="creation"
    
    if stack_exists "$STACK_NAME"; then
        if [[ "$UPDATE_STACK" == "true" ]]; then
            cmd="update-stack"
            operation="update"
            log "Updating existing stack: $STACK_NAME"
        else
            error "Stack $STACK_NAME already exists. Use --update to update it."
        fi
    else
        log "Creating new stack: $STACK_NAME"
    fi

    aws cloudformation $cmd \
        --stack-name $STACK_NAME \
        --template-body file://ir-infrastructure.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=RetentionDays,ParameterValue=$RETENTION_DAYS

    wait_for_stack $operation
}

# Get Lambda function name from stack outputs
get_lambda_function_name() {
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs[?OutputKey==`CollectorFunctionName`].OutputValue' \
        --output text
}

# Function to fetch latest IR data
fetch_latest_ir_data() {
    local bucket_name=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`DataBucketName`].OutputValue' \
        --output text)

    if [ -z "$bucket_name" ]; then
        error "Could not get IR data bucket name from stack outputs"
    fi

    log "Fetching latest IR data from bucket: $bucket_name"
    local latest_file=$(aws s3 ls "s3://${bucket_name}/ir_data/" | sort | tail -n 1 | awk '{print $4}')
    
    if [ -z "$latest_file" ]; then
        warning "No IR data files found in bucket"
        return 1
    fi

    local output_file="ir_data_${TIMESTAMP}.json"
    aws s3 cp "s3://${bucket_name}/ir_data/${latest_file}" - | jq '.' > "$output_file"
    log "IR data saved to: $output_file"
}

# Optimized cleanup function
cleanup_resources() {
    log "Starting cleanup..."
    
    # Get the IR data bucket name
    local ir_bucket_name=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`DataBucketName`].OutputValue' \
        --output text)

    # Empty and delete buckets in parallel
    if [ ! -z "$ir_bucket_name" ]; then
        aws s3 rm "s3://${ir_bucket_name}" --recursive &
        aws s3 rm "s3://${S3_BUCKET}" --recursive &
        wait
    fi

    # Delete the CloudFormation stack
    log "Deleting CloudFormation stack ${STACK_NAME}..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME"
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
    
    log "Cleanup completed!"
}

# Main deployment process
main() {
    log "Starting deployment with stack name: $STACK_NAME"
    
    # Check required files
    [ -f "ir-infrastructure.yaml" ] || error "ir-infrastructure.yaml not found!"
    [ -f "ir-collector.zip" ] || error "ir-collector.zip not found!"
    
    # Initialize S3 and upload Lambda
    ensure_s3_bucket
    upload_lambda
    
    # Deploy stack
    deploy_stack
    
    # Get Lambda function name and invoke
    LAMBDA_FUNCTION=$(get_lambda_function_name)
    log "Invoking Lambda function: $LAMBDA_FUNCTION"
    aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION" \
        --payload '{}' \
        response.json || error "Failed to invoke Lambda function"
    
    # Wait for Lambda execution
    sleep 10
    
    # Fetch IR data
    fetch_latest_ir_data
    
    # Cleanup resources
    cleanup_resources
    
    log "Deployment completed successfully!"
}

# Parse command line arguments and run main
parse_args "$@"
main