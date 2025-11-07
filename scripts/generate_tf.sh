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
  kafka_id            = var.kafka_id                
  kafka_rest_endpoint = var.kafka_rest_endpoint        
  kafka_api_key       = var.kafka_api_key              
  kafka_api_secret    = var.kafka_api_secret  
}

resource "confluent_kafka_topic" "topic" {
  topic_name       = "$TOPIC_NAME"
  partitions_count = $PARTITIONS
  config = {
    "cleanup.policy" = "delete"
  }
}

variable "kafka_api_key" {}
variable "kafka_api_secret" {}
variable "kafka_id" {}
variable "kafka_rest_endpoint" {}
EOF
