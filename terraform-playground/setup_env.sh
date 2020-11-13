#!/bin/bash
# Exporting environment variables and setting them as
# TF_VAR prefixed names so we don't have to manually pass them to terraform via -var.

export TF_VAR_aws_access_key=$AWS_ACCESS_KEY_ID
export TF_VAR_aws_secret_key=$AWS_SECRET_ACCESS_KEY
export TF_VAR_aws_account_id=$AWS_ACCOUNT_ID
export TF_VAR_aws_region=$AWS_REGION
