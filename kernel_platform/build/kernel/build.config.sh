#!/bin/bash

# --- 1. 定点爆破：穿透随机哈希目录 ---
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 手术清单 ---
CONFIGS=(
    "KNOX_NCM" "SEC_RESTRICT_FORK" "SEC_RESTRICT_ROOTING"
    "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA"
    "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX"
)

ENABLE=(
    "KSU" 
    "KSU_SUSFS" 
    "KSU_SUSFS_SUS_MOUNT" 
    "KSU_SUSFS_SUS_PATH" 
    "KSU_SUSFS_HAS_KSU_SUSFS" 
    "KSU_SUSFS_SUS_MEMFD" 
    "KSU_SUSFS_SUS_KSTAT" 
    "KSU_SUSFS_TRY_UMUNT" 
    "KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT" 
    "KSU_SUSFS_SPOOF_UNAME" 
    "KSU_SUSFS_ENABLE_LOG" 
    "KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS" 
    "KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG" 
    "KSU_SUSFS_OPEN_REDIRECT" 
    "KSU_SUSFS_SUS_MAP" 
    "KPM" 
    "KPROBES" 
    "KPROBE_EVENTS" 
    "HAVE_KPROBES" 
    "CPU_FREQ_GOV_PERFORMANCE" 
    "CPU_FREQ_GOV_USERSPACE"
)

NEW_VERSION="-SukiSU-Ultra"

# --- 3. 引擎 ---
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"
COUNT=0

# 一次性构建最终覆盖块
PAYLOAD=$(cat <<EOF

# --- SUKISU HIJACK FINAL OVERRIDE ---
CONFIG_LOCALVERSION="${NEW_VERSION}"
$(for c in "${ENABLE[@]}"; do echo "CONFIG_$c=y"; done)
$(for c in "${CONFIGS[@]}"; do echo "# CONFIG_$c is not set"; done)
# --- END SUKISU ---
EOF
)

echo "🚀 [$(date +%T)] 极速劫持：只追加不删除，靠后覆盖优先"

while true; do
  for f in ${TARGETS[@]}; do
    [ ! -f "$f" ] && continue

    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    [ -z "$ts" ] && continue

    old_ts=$(awk -v f="$f" '$1==f{print $2}' "$TIME_DB" 2>/dev/null)
    old_ts=${old_ts:-0}

    if [ "$ts" -gt "$old_ts" ]; then
      ((COUNT++))

      # 🔥 核心：只追加，不删除，一次写入，速度拉满
      echo "$PAYLOAD" >> "$f"
      sync "$f"

      # 更新时间戳
      awk -v f="$f" -v ts="$ts" '$1!=f' "$TIME_DB" > "$TIME_DB.tmp"
      echo "$f $ts" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"

      echo "::notice title=极速注入::$f (第 $COUNT 次)"
    fi
  done
  sleep 0.1
done

