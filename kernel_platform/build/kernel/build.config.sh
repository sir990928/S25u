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

# 一次性生成 PAYLOAD（更快更稳定）
PAYLOAD=$(cat <<EOF

# --- SUKISU HIJACK START ---
CONFIG_LOCALVERSION="${NEW_VERSION}"
$(for cfg in "${ENABLE[@]}"; do echo "CONFIG_$cfg=y"; done)
$(for cfg in "${CONFIGS[@]}"; do echo "# CONFIG_$cfg is not set"; done)
# --- SUKISU HIJACK END ---
EOF
)

# 构建正确的单行正则，一次删除所有旧配置
ALL_SYMS=("${CONFIGS[@]}" "${ENABLE[@]}")
PATTERN="^CONFIG_LOCALVERSION=.*"
for s in "${ALL_SYMS[@]}"; do
    PATTERN+="|^CONFIG_$s=.*|^# CONFIG_$s is not set"
done

echo "🚀 [$(date +%T)] 劫持引擎点火：全量覆盖模式"

while true; do
  for f in ${TARGETS[@]}; do
    [ ! -f "$f" ] && continue

    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    [ -z "$ts" ] && continue

    old_ts=$(awk -v f="$f" '$1 == f {print $2}' "$TIME_DB" 2>/dev/null)
    old_ts=${old_ts:-0}

    if [ "$ts" -gt "$old_ts" ]; then
      ((COUNT++))

      # 一次删除，一次写入，极快，无重复
      sed -i -E "/($PATTERN)/d" "$f"
      echo -e "$PAYLOAD" >> "$f"
      sync "$f"

      # 更新时间戳
      new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
      awk -v f="$f" -v ts="${new_ts:-$ts}" '$1 != f' "$TIME_DB" > "$TIME_DB.tmp"
      echo "$f $ts" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"

      echo "::notice title=劫持成功::已注入 $f (第 $COUNT 次)"
      echo "💎 [$(date +%T)] 修改完成：$f"
    fi
  done
  sleep 0.1
done

