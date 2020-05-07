#!/bin/bash

# This script will remove the Automated pipeline, IAM Roles, and a ServiceCatalog Portfolio created by the install.sh.  

ACC=$(aws sts get-caller-identity --query 'Account' | tr -d '"')
# add child accounts as space delimited list. 
# You will need to ensure StackSet IAM roles are correctly setup in each child account
childAcc=""
allACC="$ACC $childAcc"
allregions="us-east-1 us-east-2 us-west-1"
export AWS_DEFAULT_REGION=us-east-1
echo "Using Account:$ACC  Region:$AWS_DEFAULT_REGION Child Accounts:$childAcc All Regions:$allregions"

# multi account multi region, CF StackSet
echo "Deleting the ServiceCatalog Portfolio StackSet, this make take a while."
SSOPID=$(aws cloudformation delete-stack-instances --stack-set-name SC-IAC-automated-portfolio --accounts $allACC --regions $allregions --operation-preferences FailureToleranceCount=1,MaxConcurrentCount=3 --no-retain-stacks | jq '.OperationId' | tr -d '"')
STATUS=""
until [ "$STATUS" = "SUCCEEDED" ]; do 
  STATUS=$(aws cloudformation describe-stack-set-operation --stack-set-name SC-IAC-automated-portfolio --operation-id $SSOPID | jq '.StackSetOperation.Status' | tr -d '"')
  echo "waiting for portfolio Stackset to delete. current status: $STATUS"
  sleep 5
done;

aws cloudformation delete-stack-set --stack-set-name SC-IAC-automated-portfolio

echo "Deleting the ServiceCatalog IAM roles StackSet, this make take a while."
SSOPID=$(aws cloudformation delete-stack-instances --stack-set-name SC-IAC-automated-IAMroles --accounts $allACC --regions $AWS_DEFAULT_REGION --operation-preferences FailureToleranceCount=1,MaxConcurrentCount=1 --no-retain-stacks | jq '.OperationId' | tr -d '"')
STATUS=""
until [ "$STATUS" = "SUCCEEDED" ]; do 
  STATUS=$(aws cloudformation describe-stack-set-operation --stack-set-name SC-IAC-automated-IAMroles --operation-id $SSOPID | jq '.StackSetOperation.Status' | tr -d '"')
  echo "waiting for IAM role Stackset to delete. current status: $STATUS"
  sleep 10
done;

aws cloudformation delete-stack-set --stack-set-name SC-IAC-automated-IAMroles

echo "Clearing out the Automation pipeline S3 buckets"
# edit your bucket names here
aws s3 rb s3://sc-ra-iacpipeline-pipelineartifacts-????? --force
aws s3 rb s3://sc-ra-iacpipeline-deployedtemplates-????? --force

echo "Deleting the automated pipeline stack."
aws cloudformation delete-stack --stack-name SC-RA-IACPipeline

echo "Deleting the StackSet IAM roles."
aws cloudformation delete-stack --stack-name IAM-StackSetAdministrator 
aws cloudformation delete-stack --stack-name IAM-StackSetExecution 

echo "Complete.  See CloudFormation Stacks and StackSets Console in each region ($allregions) to confirm all resources have been removed."