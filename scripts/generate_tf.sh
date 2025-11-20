#!/bin/bash
set -euo pipefail

echo "----------------------------------------"
echo "Starting Terraform generation script"
echo "----------------------------------------"

REQUESTS_DIR="requests"

if [[ ! -d "$REQUESTS_DIR" ]]; then
  echo "ERROR: requests/ directory does not exist."
  exit 1
fi

###############################################
# 1. Determine which metadata.json to use
###############################################

# Preferred: Use commit SHA from CodePipeline/CodeBuild
if [[ -n "${CODEBUILD_RESOLVED_SOURCE_VERSION:-}" ]]; then
  echo "🔎 Using commit SHA from CodeBuild: $CODEBUILD_RESOLVED_SOURCE_VERSION"

  COMMIT_DIR=$(find "$REQUESTS_DIR" -type d -name "*$CODEBUILD_RESOLVED_SOURCE_VERSION*" | head -n 1 || true)

  if [[ -n "$COMMIT_DIR" ]]; then
    METADATA_FILE="$COMMIT_DIR/metadata.json"
  fi
fi

# Fallback: Use newest PR folder
if [[ -z "${METADATA_FILE:-}" || ! -f "$METADATA_FILE" ]]; then
  echo "⚠️  WARNING: Could not match commit to folder. Using latest metadata.json instead..."

  METADATA_FILE=$(find "$REQUESTS_DIR" -type f -name metadata.json -printf "%T@ %p\n" \
    | sort -nr | head -n 1 | cut -d' ' -f2-)
fi

if [[ -z "$METADATA_FILE" || ! -f "$METADATA_FILE" ]]; then
  echo "ERROR: No metadata.json found!"
  exit 1
fi

echo "📄 Using metadata file: $METADATA_FILE"

###############################################
# 2. Extract JSON fields
###############################################

TOPIC_NAME=$(jq -r '.topic_name // empty' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions // empty' "$METADATA_FILE")
DESCRIPTION=$(jq -r '.description // empty' "$METADATA_FILE")

if [[ -z "$TOPIC_NAME" || -z "$PARTITIONS" ]]; then
  echo "ERROR: metadata.json missing required fields."
  jq . "$METADATA_FILE"
  exit 1
fi

echo "🔧 Extracted values:"
echo "   topic_name: $TOPIC_NAME"
echo "   partitions: $PARTITIONS"
echo "   description: ${DESCRIPTION:-<none>}"

###############################################
# 3. Generate Terraform configuration
###############################################

echo "Cleaning old tf/ folder..."
rm -rf tf
mkdir tf

echo "Writing tf/main.tf ..."

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
}

variable "confluent_api_key" {}
variable "confluent_api_secret" {}
variable "kafka_id" {}
variable "kafka_rest_endpoint" {}
EOF

echo "Terraform config generation complete!"
echo "----------------------------------------"
