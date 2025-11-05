#!/bin/bash
set -e  # exit immediately if any command fails

# Create directory for Terraform files
mkdir -p tf

# Pick the first metadata.json found
METADATA_FILE=$(find requests -name metadata.json | head -n 1)
echo "Generating Terraform from: $METADATA_FILE"

# Extract fields from metadata.json
TOPIC_NAME=$(jq -r '.topic_name' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions' "$METADATA_FILE")

# Extract Confluent credentials from environment variables
# Make sure these are exported in your buildspec
# CONFLUENT_API_KEY, CONFLUENT_API_SECRET, KAFKA_CLUSTER, CONFLUENT_ENV, CONFLUENT_REST_ENDPOINT
if [[ -z "$CONFLUENT_API_KEY" || -z "$CONFLUENT_API_SECRET" || -z "$KAFKA_CLUSTER" || -z "$CONFLUENT_REST_ENDPOINT" ]]; then
  echo "ERROR: One or more required environment variables are missing."
  exit 1
fi

echo "Using Kafka cluster ID: $KAFKA_CLUSTER"
echo "Using REST endpoint: $CONFLUENT_REST_ENDPOINT"
echo "Using environment ID: $CONFLUENT_ENV"

# Generate main.tf dynamically
cat > tf/main.tf <<EOF
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.5.0"
    }
  }
}

provider "confluent" {
  kafka_api_key       = var.confluent_api_key
  kafka_api_secret    = var.confluent_api_secret
  kafka_rest_endpoint = var.confluent_rest_endpoint
  environment         = var.confluent_env
}

resource "confluent_kafka_topic" "topic" {
  kafka_cluster {
    id = var.kafka_cluster
  }

  topic_name       = "$TOPIC_NAME"
  partitions_count = $PARTITIONS
  config = {
    "cleanup.policy" = "delete"
  }
  rest_endpoint = var.confluent_rest_endpoint
}

# Variables
variable "confluent_api_key" {}
variable "confluent_api_secret" {}
variable "kafka_cluster" {}
variable "confluent_env" {}
variable "confluent_rest_endpoint" {}
EOF

echo "Terraform configuration generated successfully in tf/main.tf"
