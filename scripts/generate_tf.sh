#!/bin/bash
set -e

echo "Fetching commit metadata..."
METADATA_FILE=$(find requests -type f -name metadata.json -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d' ' -f2-)


if [[ -z "$METADATA_FILE" ]]; then
  echo "ERROR: No metadata.json found in commit. Aborting."
  exit 1
fi

echo "Using metadata: $METADATA_FILE"

# Extract values
TOPIC_NAME=$(jq -r '.topic_name' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions' "$METADATA_FILE")
DESCRIPTION=$(jq -r '.description' "$METADATA_FILE")

# Generate TF folder
rm -rf tf
mkdir tf

cat > tf/main.tf <<EOF
terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
      version = "2.5.0"
    }
  }
}

provider "confluent" {
  kafka_id            = var.kafka_id                   #
  kafka_rest_endpoint = var.kafka_rest_endpoint
  kafka_api_key    = var.confluent_api_key
  kafka_api_secret = var.confluent_api_secret
}

resource "confluent_kafka_topic" "topic" {
  topic_name       = "$TOPIC_NAME"
  partitions_count = $PARTITIONS
}

variable "confluent_api_key" {}
variable "confluent_api_secret" {}
variable "kafka_id" {}
variable "kafka_rest_endpoint" {}
EOF
