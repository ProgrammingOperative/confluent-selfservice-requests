#!/bin/bash
set -euo pipefail

echo "----------------------------------------"
echo "🔧 Starting Terraform generation script"
echo "----------------------------------------"

BASE_DIR="requests/topics"

# Commit SHA CodePipeline triggered from
COMMIT_SHA="${CODEBUILD_RESOLVED_SOURCE_VERSION}"

echo "📝 Pipeline triggered by commit: $COMMIT_SHA"

# Get list of changed files in this commit
CHANGED=$(git diff-tree --no-commit-id --name-only -r "$COMMIT_SHA")

echo "🔍 Files changed in commit:"
echo "$CHANGED"

# Find the folder that contains metadata.json
TARGET_FOLDER=""
for f in $CHANGED; do
  if [[ "$f" == requests/topics/*/metadata.json ]]; then
    TARGET_FOLDER=$(dirname "$f")
    break
  fi
done

if [[ -z "$TARGET_FOLDER" ]]; then
  echo "❌ ERROR: No metadata.json changed in this commit!"
  exit 1
fi

echo "✅ Using folder from commit: $TARGET_FOLDER"

METADATA_FILE="$TARGET_FOLDER/metadata.json"

echo "📄 Reading metadata: $METADATA_FILE"

TOPIC_NAME=$(jq -r '.topic_name' "$METADATA_FILE")
PARTITIONS=$(jq -r '.partitions' "$METADATA_FILE")
DESCRIPTION=$(jq -r '.description // "<none>"' "$METADATA_FILE")

echo "✔ Extracted metadata:"
echo "   topic_name: $TOPIC_NAME"
echo "   partitions: $PARTITIONS"
echo "   description: $DESCRIPTION"

# Prepare output
rm -rf tf
mkdir -p tf

cat <<EOF > tf/main.tf
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

echo "🎉 Terraform file generated successfully!"
echo "----------------------------------------"
