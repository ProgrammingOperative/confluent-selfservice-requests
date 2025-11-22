#!/usr/bin/env bash
set -euo pipefail

echo "----------------------------------------"
echo "🔧 Starting Terraform generation script"
echo "----------------------------------------"

REQUESTS_DIR="requests/topics"

if [[ ! -d "$REQUESTS_DIR" ]]; then
  echo "❌ Directory '$REQUESTS_DIR' does not exist!"
  exit 1
fi

echo "🔍 Locating most recently updated metadata.json..."

# Find newest metadata.json file in the topics directory
LATEST_META=$(find "$REQUESTS_DIR" -type f -name "metadata.json" -printf "%T@ %p\n" \
    | sort -nr \
    | head -n 1 \
    | awk '{print $2}')

if [[ -z "$LATEST_META" ]]; then
  echo "❌ No metadata.json found!"
  exit 1
fi

TARGET_DIR=$(dirname "$LATEST_META")
echo "✅ Using newest request folder: $TARGET_DIR"

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
  cloud_api_key       = var.confluent_api_key
  cloud_api_secret    = var.confluent_api_secret
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
