#!/usr/bin/env bash
set -euo pipefail

echo "----------------------------------------"
echo "🔧 Starting Terraform generation script"
echo "----------------------------------------"

# CodePipeline → CodeBuild set this automatically
COMMIT_SHA="${CODEBUILD_RESOLVED_SOURCE_VERSION:-unknown}"
echo "📝 Pipeline triggered by commit: $COMMIT_SHA"

REQUESTS_DIR="requests/topics"
TARGET_DIR=""

if [[ ! -d "$REQUESTS_DIR" ]]; then
  echo "❌ Directory '$REQUESTS_DIR' does not exist!"
  exit 1
fi

echo "🔍 Searching for matching folder with commit_sha..."

for FOLDER in "$REQUESTS_DIR"/*; do
  [[ -d "$FOLDER" ]] || continue

  META="$FOLDER/metadata.json"

  if [[ -f "$META" ]]; then
    META_SHA=$(jq -r '.commit_sha // empty' "$META")

    if [[ "$META_SHA" == "$COMMIT_SHA" ]]; then
      TARGET_DIR="$FOLDER"
      break
    fi
  fi
done

if [[ -z "$TARGET_DIR" ]]; then
  echo "❌ No folder found whose metadata.json contains commit_sha: $COMMIT_SHA"
  exit 1
fi

echo "✅ Found matching folder: $TARGET_DIR"

# Parse metadata
TOPIC_NAME=$(jq -r '.topic_name' "$TARGET_DIR/metadata.json")
PARTITIONS=$(jq -r '.partitions' "$TARGET_DIR/metadata.json")
DESCRIPTION=$(jq -r '.description' "$TARGET_DIR/metadata.json")

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
EOF

echo "🎉 Terraform config generation complete!"
echo "----------------------------------------"
