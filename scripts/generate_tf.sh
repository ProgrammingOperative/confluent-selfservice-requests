#!/bin/bash
set -e

echo "=== Detecting changed request folder ==="

# Detect the directory under "requests/" changed in this commit
# Works for both PR builds and normal merges
CHANGED_REQUEST_DIR=$(git diff --name-only HEAD~1 HEAD | grep "^requests/" | cut -d"/" -f1-2 | uniq)

if [[ -z "$CHANGED_REQUEST_DIR" ]]; then
  echo "ERROR: No request folder changed in this commit. Aborting."
  exit 1
fi

# Safety check: ensure only ONE folder was changed
COUNT=$(echo "$CHANGED_REQUEST_DIR" | wc -l)
if [[ "$COUNT" -gt 1 ]]; then
  echo "ERROR: Multiple request folders changed:"
  echo "$CHANGED_REQUEST_DIR"
  echo "Please modify only ONE request folder per PR."
  exit 1
fi

echo "Using request folder: $CHANGED_REQUEST_DIR"

METADATA_FILE="${CHANGED_REQUEST_DIR}/metadata.json"

if [[ ! -f "$METADATA_FILE" ]]; then
  echo "ERROR: metadata.json not found at $METADATA_FILE"
  exit 1
fi

echo "=== Reading metadata from $METADATA_FILE ==="

TOPIC_NAME=$(jq -r '.topic_name' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions' "$METADATA_FILE")
DESCRIPTION=$(jq -r '.description' "$METADATA_FILE")

if [[ -z "$TOPIC_NAME" || -z "$PARTITIONS" ]]; then
  echo "ERROR: metadata.json missing required keys (topic_name, partitions)"
  exit 1
fi

echo "Metadata OK:"
echo "  Topic Name : $TOPIC_NAME"
echo "  Partitions : $PARTITIONS"
echo "  Description: ${DESCRIPTION:-<none>}"

# Create clean TF folder
rm -rf tf
mkdir tf

echo "=== Generating Terraform file ==="

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
  kafka_api_key       = var.confluent_api_key
  kafka_api_secret    = var.confluent_api_secret
}

resource "confluent_kafka_topic" "topic" {
  topic_name       = "$TOPIC_NAME"
  partitions_count = $PARTITIONS

  kafka_cluster {
    id = var.kafka_id
  }

  config = {
    "cleanup.policy" = "delete"
  }
}

variable "confluent_api_key" {}
variable "confluent_api_secret" {}
variable "kafka_id" {}
variable "kafka_rest_endpoint" {}
EOF

echo "=== TF generation complete ==="
echo "Generated: tf/main.tf"
echo "=============================="
