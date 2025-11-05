#!/bin/bash
set -e  # exit if any command fails

# Create directory for Terraform files
mkdir -p tf

# Pick the first metadata.json found
METADATA_FILE=$(find requests -name metadata.json | head -n 1)
echo "Generating Terraform from: $METADATA_FILE"

# Extract fields
TOPIC_NAME=$(jq -r '.topic_name' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions' "$METADATA_FILE")

# Generate main.tf
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
  kafka_api_key    = var.confluent_api_key
  kafka_api_secret = var.confluent_api_secret
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
  rest_endpoint = "https://api.confluent.cloud"
}

variable "confluent_api_key" {}
variable "confluent_api_secret" {}
variable "kafka_cluster" {}
EOF
