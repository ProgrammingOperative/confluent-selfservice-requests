#!/bin/bash
set -e

mkdir -p tf

METADATA_FILE=$(find requests -name metadata.json | head -n 1)
echo "Generating Terraform from: $METADATA_FILE"

TOPIC_NAME=$(jq -r '.topic_name' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions' "$METADATA_FILE")

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
  kafka_api_key        = var.confluent_api_key
  kafka_api_secret     = var.confluent_api_secret
  kafka_rest_endpoint  = var.confluent_rest_endpoint
}

resource "confluent_kafka_topic" "topic" {
  kafka_cluster {
    id = var.kafka_cluster
    environment {
      id = var.confluent_env
    }
  }
  topic_name       = "$TOPIC_NAME"
  partitions_count = $PARTITIONS
  config = {
    "cleanup.policy" = "delete"
  }
  rest_endpoint = var.confluent_rest_endpoint
}

variable "confluent_api_key" {}
variable "confluent_api_secret" {}
variable "kafka_cluster" {}
variable "confluent_env" {}
variable "confluent_rest_endpoint" {}
EOF
