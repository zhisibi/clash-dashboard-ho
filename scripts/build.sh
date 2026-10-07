#!/usr/bin/env bash
# 用 HarmonyOS Command Line Tools 在 Linux/macOS 命令行构建未签名 HAP
# 用法：CLT_HOME=/path/to/command-line-tools ./scripts/build.sh [debug|release]
set -e
CLT_HOME=${CLT_HOME:-$HOME/command-line-tools}
export DEVECO_SDK_HOME=${DEVECO_SDK_HOME:-$CLT_HOME/sdk}
export PATH=$CLT_HOME/bin:$PATH
cd "$(dirname "$0")/.."
hvigorw --mode module -p module=entry@default -p product=default -p buildMode=${1:-release} assembleHap --no-daemon
ls -la entry/build/default/outputs/default/*.hap
