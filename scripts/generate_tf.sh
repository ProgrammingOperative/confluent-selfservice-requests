#!/usr/bin/env bash
set -euo pipefail

echo "----------------------------------------"
echo "Selecting latest topic request by PR number"
echo "----------------------------------------"

REQUESTS_DIR="requests/topics"

if [[ ! -d "$REQUESTS_DIR" ]]; then
  echo "Directory '$REQUESTS_DIR' does not exist!"
  exit 1
fi

HIGHEST_PR=0
TARGET_META=""

# Iterate through topic request folders
for FOLDER in "$REQUESTS_DIR"/*; do
  [[ -d "$FOLDER" ]] || continue

  META="$FOLDER/metadata.json"

  if [[ -f "$META" ]]; then
    PR_NUM=$(jq -r '.pr_number // 0' "$META")

    if [[ "$PR_NUM" =~ ^[0-9]+$ ]]; then
      if (( PR_NUM > HIGHEST_PR )); then
        HIGHEST_PR=$PR_NUM
        TARGET_META="$META"
      fi
    fi
  fi
done

if [[ "$HIGHEST_PR" -eq 0 ]]; then
  echo "No valid pr_number found in any metadata.json!"
  exit 1
fi

echo "Latest PR detected: $HIGHEST_PR"
echo "Using metadata file: $TARGET_META"

# Extract fields
TOPIC_NAME=$(jq -r '.topic_name' "$TARGET_META")
PARTITIONS=$(jq -r '.partitions' "$TARGET_META")
DESCRIPTION=$(jq -r '.description // ""' "$TARGET_META")

echo "Parsed metadata:"
echo "   • topic_name  = $TOPIC_NAME"
echo "   • partitions  = $PARTITIONS"
echo "   • description = $DESCRIPTION"

# Generate Terraform file (always overwrites)
echo "Writing tf/main.tf"

mkdir -p tf

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
