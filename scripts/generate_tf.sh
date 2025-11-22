#!/usr/bin/env bash
set -euo pipefail

echo "----------------------------------------"
echo "🔧 Starting Terraform generation script"
echo "----------------------------------------"

REQUESTS_DIR="requests/topics"
TARGET_DIR=""

# Extract PR number from webhook or source reference
PR_NUMBER=$(echo "${CODEBUILD_WEBHOOK_TRIGGER:-}" | grep -oE '[0-9]+' | head -n 1 || true)

if [[ -z "$PR_NUMBER" ]]; then
  PR_NUMBER=$(echo "${CODEBUILD_SOURCE_VERSION:-}" | grep -oE '[0-9]+' | head -n 1 || true)
fi

if [[ -z "$PR_NUMBER" ]]; then
  echo "❌ Unable to detect PR number from environment!"
  exit 1
fi

echo "📝 Pipeline associated with PR number: $PR_NUMBER"

if [[ ! -d "$REQUESTS_DIR" ]]; then
  echo "❌ Directory '$REQUESTS_DIR' does not exist!"
  exit 1
fi

echo "🔍 Searching for metadata.json with pr_number=$PR_NUMBER ..."

# Find the metadata.json that belongs to this PR
META=$(grep -rl "\"pr_number\": $PR_NUMBER" "$REQUESTS_DIR" || true)

if [[ -z "$META" ]]; then
  echo "❌ No metadata.json found for PR number: $PR_NUMBER"
  exit 1
fi

TARGET_DIR=$(dirname "$META")

echo "✅ Found matching request folder: $TARGET_DIR"

# Extract values using jq
TOPIC_NAME=$(jq -r '.topic_name' "$LATEST_META")
PARTITIONS=$(jq -r '.partitions' "$LATEST_META")
DESCRIPTION=$(jq -r '.description' "$LATEST_META")

mkdir -p tf

echo "📝 Generating Terraform file: tf/main.tf"

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
  topic_name       = "${TOPIC_NAME}"
  partitions_count = ${PARTITIONS}

  config = {
    "description" = "${DESCRIPTION}"
  }

  kafka_cluster {
    id = var.kafka_id
  }
}

variable "kafka_id" {
  description = "The Kafka cluster ID"
  type        = string
}
variable "kafka_rest_endpoint" {
  description = "The Kafka REST endpoint"
  type        = string
}
variable "confluent_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
}
variable "confluent_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
}
EOF

echo "🎉 Terraform config generation complete!"
echo "----------------------------------------"
