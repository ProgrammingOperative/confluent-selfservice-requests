#!/bin/bash
set -e

echo "Fetching commit metadata..."
COMMIT=$(jq -r '.build.sourceVersion' /codebuild/output/tmp/codebuild.json 2>/dev/null || echo "$CODEBUILD_RESOLVED_SOURCE_VERSION")

echo "Finding metadata.json modified in commit: $COMMIT"
METADATA_FILE=$(git diff-tree --no-commit-id --name-only -r $COMMIT | grep "metadata.json" | head -n 1)

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
  cloud_api_key    = var.confluent_api_key
  cloud_api_secret = var.confluent_api_secret
}

resource "confluent_kafka_topic" "topic" {
  kafka_cluster {
    id = var.kafka_cluster
  }
  topic_name       = "$TOPIC_NAME"
  partitions_count = $PARTITIONS
  rest_endpoint    = "https://api.confluent.cloud"
}

variable "confluent_api_key" {}
variable "confluent_api_secret" {}
variable "kafka_cluster" {}
EOF
