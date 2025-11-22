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

echo "📁 Scanning request folders..."
TARGET_DIR=""

for FOLDER in "$REQUESTS_DIR"/*; do
  [[ -d "$FOLDER" ]] || continue

  META="$FOLDER/metadata.json"

  if [[ -f "$META" ]]; then
    EXPECTED_FOLDER=$(basename "$FOLDER")
    META_FOLDER=$(jq -r '.folder_name // empty' "$META")

    if [[ "$META_FOLDER" == "$EXPECTED_FOLDER" ]]; then
      TARGET_DIR="$FOLDER"
      break
    fi
  fi
done

if [[ -z "$TARGET_DIR" ]]; then
  echo "❌ No folder contains metadata.folder_name matching its actual name"
  exit 1
fi

echo "✅ Found matching folder: $TARGET_DIR"

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
