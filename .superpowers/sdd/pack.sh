#!/usr/bin/env bash
# Pack the mobile tree so it can be uploaded to the test host.
set -euo pipefail
cd /home/mimin/projects/anchorx/mobile
tar czf /home/mimin/anchor-sync.tgz \
  --exclude=build --exclude=.dart_tool --exclude=android/.gradle --exclude=ios/Pods .
ls -la /home/mimin/anchor-sync.tgz
