#!/bin/bash

INSTANCE_ID="$1"
ACTION="$2"
OFFSET="${3:-1}"  # default to latest snapshot
DRY_RUN=false

if [[ "$3" == "--dry-run" || "$4" == "--dry-run" ]]; then
  DRY_RUN=true
fi

REGION="eu-west-1"
KEEP_SNAPSHOTS=3
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

set -e

print_usage() {
  echo ""
  echo "📘 EC2 Root Snapshot Manager - Usage Guide"
  echo ""
  echo "✅ Usage:"
  echo "  ./ec2-root-snapshot-mgr.sh <instance-id> snapshot"
  echo "      → Create a tagged snapshot of the root volume"
  echo ""
  echo "  ./ec2-root-snapshot-mgr.sh <instance-id> revert [offset] [--dry-run]"
  echo "      → Revert to a previous snapshot"
  echo "      → offset: 1 = latest (default), 2 = second latest, etc."
  echo ""
  echo "🧪 Dry-run example:"
  echo "  ./ec2-root-snapshot-mgr.sh <instance-id> revert 2 --dry-run"
  echo ""
  echo "⚠️ Snapshots are filtered by tags: CreatedBy=ec2-root-snapshot-mgr.sh and InstanceId"
  echo ""
  exit 1
}

get_root_volume_and_device() {
  for dev in /dev/xvda /dev/sda1; do
    VOLUME_ID=$(aws ec2 describe-instances \
      --region "$REGION" \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='$dev'].Ebs.VolumeId" \
      --output text)
    if [[ "$VOLUME_ID" != "None" && -n "$VOLUME_ID" ]]; then
      echo "$VOLUME_ID|$dev"
      return
    fi
  done
  echo "❌ ERROR: No root volume found"
  exit 1
}

delete_old_snapshots() {
  local instance_id="$1"
  echo "🧹 Cleaning up old snapshots (keep latest $KEEP_SNAPSHOTS)..."
  SNAPSHOTS_TO_DELETE=$(aws ec2 describe-snapshots \
    --region "$REGION" \
    --filters Name=tag:InstanceId,Values="$instance_id" Name=tag:CreatedBy,Values=ec2-root-snapshot-mgr.sh \
    --query "Snapshots | sort_by(@, &StartTime)[:-$KEEP_SNAPSHOTS].SnapshotId" \
    --output text)

  for snap in $SNAPSHOTS_TO_DELETE; do
    echo "🗑 Deleting snapshot $snap"
    aws ec2 delete-snapshot --region "$REGION" --snapshot-id "$snap"
  done
}

# Show help if called wrong
if [[ "$INSTANCE_ID" == "--help" || "$ACTION" == "--help" || -z "$INSTANCE_ID" || -z "$ACTION" ]]; then
  print_usage
fi

if [[ "$ACTION" == "snapshot" ]]; then
  IFS='|' read -r VOLUME_ID DEVICE <<< "$(get_root_volume_and_device)"
  echo "📦 Snapshotting volume: $VOLUME_ID | Device: $DEVICE"

  SNAPSHOT_ID=$(aws ec2 create-snapshot \
    --region "$REGION" \
    --volume-id "$VOLUME_ID" \
    --description "Snapshot of $INSTANCE_ID at $TIMESTAMP" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=RootBackup-$INSTANCE_ID-$TIMESTAMP},{Key=CreatedBy,Value=ec2-root-snapshot-mgr.sh},{Key=InstanceId,Value=$INSTANCE_ID}]" \
    --query "SnapshotId" --output text)

  echo "✅ Snapshot created: $SNAPSHOT_ID"
  delete_old_snapshots "$INSTANCE_ID"

elif [[ "$ACTION" == "revert" ]]; then
  OFFSET_INDEX=$((OFFSET - 1))
  echo "🔍 Searching for snapshot at offset $OFFSET (index $OFFSET_INDEX)..."

  SNAPSHOT_ID=$(aws ec2 describe-snapshots \
    --region "$REGION" \
    --filters Name=tag:InstanceId,Values="$INSTANCE_ID" Name=tag:CreatedBy,Values=ec2-root-snapshot-mgr.sh \
    --query "reverse(sort_by(Snapshots, &StartTime))[$OFFSET_INDEX].SnapshotId" \
    --output text)

  if [[ "$SNAPSHOT_ID" == "None" || -z "$SNAPSHOT_ID" ]]; then
    echo "❌ No matching snapshot found for instance $INSTANCE_ID"
    exit 1
  fi

  IFS='|' read -r VOLUME_ID DEVICE <<< "$(get_root_volume_and_device)"
  echo "📄 Current volume: $VOLUME_ID | Root device: $DEVICE"
  echo "📍 Selected snapshot: $SNAPSHOT_ID"

  if $DRY_RUN; then
    echo ""
    echo "🧪 DRY-RUN: Here's what would happen:"
    echo "  - Stop instance $INSTANCE_ID"
    echo "  - Detach volume $VOLUME_ID"
    echo "  - Create volume from $SNAPSHOT_ID"
    echo "  - Attach to $INSTANCE_ID as $DEVICE"
    echo "  - Start instance"
    echo ""
    exit 0
  fi

  echo "❓ Confirm revert to snapshot $SNAPSHOT_ID? [y/N]"
  read -r CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "❌ Cancelled by user."
    exit 0
  fi

  echo "🛑 Stopping instance $INSTANCE_ID..."
  aws ec2 stop-instances --region "$REGION" --instance-ids "$INSTANCE_ID"
  aws ec2 wait instance-stopped --region "$REGION" --instance-ids "$INSTANCE_ID"

  echo "📛 Detaching current root volume..."
  aws ec2 detach-volume --region "$REGION" --volume-id "$VOLUME_ID"
  aws ec2 wait volume-available --region "$REGION" --volume-ids "$VOLUME_ID"

  AZ=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].Placement.AvailabilityZone" \
    --output text)

  echo "📦 Creating volume from snapshot..."
  NEW_VOL_ID=$(aws ec2 create-volume \
    --region "$REGION" \
    --snapshot-id "$SNAPSHOT_ID" \
    --availability-zone "$AZ" \
    --volume-type gp2 \
    --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=RestoredRoot-$INSTANCE_ID-$TIMESTAMP},{Key=CreatedBy,Value=ec2-root-snapshot-mgr.sh}]" \
    --query "VolumeId" --output text)

  echo "⏳ Waiting for volume $NEW_VOL_ID..."
  aws ec2 wait volume-available --region "$REGION" --volume-ids "$NEW_VOL_ID"

  echo "🔗 Attaching $NEW_VOL_ID as $DEVICE..."
  aws ec2 attach-volume \
    --region "$REGION" \
    --volume-id "$NEW_VOL_ID" \
    --instance-id "$INSTANCE_ID" \
    --device "$DEVICE"

  echo "▶️ Starting instance..."
  aws ec2 start-instances --region "$REGION" --instance-ids "$INSTANCE_ID"

  echo "✅ Revert complete. Instance now running with volume from $SNAPSHOT_ID"

else
  echo "❌ Invalid action: $ACTION"
  print_usage
fi
