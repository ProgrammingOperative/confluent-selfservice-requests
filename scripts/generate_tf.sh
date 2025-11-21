#!/bin/bash
set -euo pipefail

echo "----------------------------------------"
echo "🔧 Starting Terraform generation script"
echo "----------------------------------------"

BASE_DIR="requests/topics"

echo "📂 Looking for latest PR folder in: $BASE_DIR"

# Find folders ending with "-<40charSHA>"
LATEST_FOLDER=$(find "$BASE_DIR" -maxdepth 1 -type d \
  -regex ".*/.*-[0-9a-f]\{40\}" \
  -printf "%T@ %p\n" | sort -n | tail -1 | awk '{print $2}')

if [[ -z "$LATEST_FOLDER" ]]; then
  echo "❌ ERROR: No valid PR metadata folders found!"
  exit 1
fi

echo "✅ Latest PR folder detected: $LATEST_FOLDER"

METADATA_FILE="$LATEST_FOLDER/metadata.json"

if [[ ! -f "$METADATA_FILE" ]]; then
  echo "❌ ERROR: metadata.json not found in $LATEST_FOLDER"
  exit 1
fi

echo "📄 Using metadata file: $METADATA_FILE"
echo "Extracting JSON fields..."

TOPIC_NAME=$(jq -r '.topic_name' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions' "$METADATA_FILE")
DESCRIPTION=$(jq -r '.description // "<none>"' "$METADATA_FILE")

echo "✔ Extracted values"
echo "   topic_name: $TOPIC_NAME"
echo "   partitions: $PARTITIONS"
echo "   description: $DESCRIPTION"

# Prepare TF folder
echo "🧹 Cleaning old tf/ folder..."
rm -rf tf
mkdir -p tf

TF_FILE="tf/main.tf"
echo "📝 Writing Terraform config to tf/main.tf ..."

cat <<EOF > "$TF_FILE"
terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.5.0"
    }
  }
}

provider "confluent" {
  kafka_id             = var.kafka_id
  kafka_rest_endpoint  = var.kafka_rest_endpoint
  cloud_api_key        = var.confluent_api_key
  cloud_api_secret     = var.confluent_api_secret
}

variable "kafka_id" {}
variable "kafka_rest_endpoint" {}
variable "confluent_api_key" {}
variable "confluent_api_secret" {}

resource "confluent_kafka_topic" "topic" {
  topic_name       = "${TOPIC_NAME}"
  partitions_count = ${PARTITIONS}

  kafka_cluster {
    id = var.kafka_id
  }
}
EOF

echo "🎉 Terraform config generation complete!"
echo "----------------------------------------"

cd tf

echo "🚀 Running terraform init"
terraform init -input=false

echo "🚀 Applying Terraform..."
terraform apply -auto-approve -input=false \
  -var="confluent_api_key=$CONFLUENT_API_KEY" \
  -var="confluent_api_secret=$CONFLUENT_API_SECRET" \
  -var="kafka_id=$KAFKA_CLUSTER" \
  -var="kafka_rest_endpoint=$CONFLUENT_REST_ENDPOINT"
