#!/bin/bash

# --- 1. 定点爆破：穿透随机哈希目录 ---
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 手术清单 (已补全 SUSFS 新版所有选项) ---
CONFIGS=("KNOX_NCM" "SEC_RESTRICT_FORK" "SEC_RESTRICT_ROOTING" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")

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

# --- 3. 引擎初始化 ---
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"
COUNT=0
export stdbuf -oL

# 提前构建 Payload (真理块)
PAYLOAD="\n# --- SUKISU HIJACK START ---\n"
PAYLOAD+="CONFIG_LOCALVERSION=\"$NEW_VERSION\"\n"
for cfg in "${ENABLE[@]}"; do PAYLOAD+="CONFIG_$cfg=y\n"; done
for cfg in "${CONFIGS[@]}"; do PAYLOAD+="# CONFIG_$cfg is not set\n"; done
PAYLOAD+="# --- SUKISU HIJACK END ---\n"

# 构建一次性删除正则
PATTERN=$(printf "|CONFIG_%s|# CONFIG_%s is not set" "${CONFIGS[@]}" "${ENABLE[@]}" "${CONFIGS[@]}" "${ENABLE[@]}")
PATTERN="^(${PATTERN:1}|CONFIG_LOCALVERSION=)"

echo "🚀 [$(date +%T)] 劫持引擎点火：全量覆盖模式 (支持 SUSFS v1.5.x+)"

while true; do
  for f in ${TARGETS[@]}; do
    [ ! -f "$f" ] && continue
    
    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    [ -z "$ts" ] && continue
    
    old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
    old_ts=${old_ts:-0}

    if [ "$ts" -gt "$old_ts" ]; then
      ((COUNT++))

      # 原子操作：先删后追
      sed -i -E "/$PATTERN/d" "$f"
      printf "$PAYLOAD" >> "$f"
      sync "$f"

      # 更新数据库
      new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
      grep -v "^$f " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
      echo "$f ${new_ts:-$ts}" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"
      
      echo "::notice title=劫持成功::已注入 $f (第 $COUNT 次)"
      echo "💎 [$(date +%T)] 修改完成：$f"
    fi
  done
  sleep 0.1
done

