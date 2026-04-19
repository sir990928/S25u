#!/bin/bash

# --- 1. 定点爆破：穿透随机哈希目录 ---
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 手术清单 ---
CONFIGS=("KNOX_NCM" "SEC_RESTRICT_FORK" "SEC_RESTRICT_ROOTING" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KSU_SUSFS" "KSU_SUSFS_SUS_MOUNT" "KSU_SUSFS_SUS_PATH" "KSU_SUSFS_HAS_KSU_SUSFS" "KSU_SUSFS_SUS_MEMFD" "KSU_SUSFS_SUS_KSTAT" "KSU_SUSFS_TRY_UMUNT" "KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT" "KPM" "KPROBES" "KPROBE_EVENTS" "HAVE_KPROBES" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VERSION="-SukiSU-Ultra"

# 初始化数据库
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"
COUNT=0

# 强制行缓冲
export stdbuf -oL

# 提前构建真理块（Payload），减少循环内的计算
PAYLOAD="\n# --- SUKISU HIJACK START ---\n"
PAYLOAD+="CONFIG_LOCALVERSION=\"$NEW_VERSION\"\n"
for cfg in "${ENABLE[@]}"; do PAYLOAD+="CONFIG_$cfg=y\n"; done
for cfg in "${CONFIGS[@]}"; do PAYLOAD+="# CONFIG_$cfg is not set\n"; done
PAYLOAD+="# --- SUKISU HIJACK END ---\n"

# 构建删除正则（一次性删除所有相关项）
# 匹配所有以 CONFIG_ 开头且在清单中的项，或者已经被注释掉的项
PATTERN=$(printf "|CONFIG_%s|# CONFIG_%s is not set" "${CONFIGS[@]}" "${ENABLE[@]}" "${CONFIGS[@]}" "${ENABLE[@]}")
PATTERN="^(${PATTERN:1}|CONFIG_LOCALVERSION=)"

echo "🚀 [$(date +%T)] 劫持引擎点火：全量原子覆盖模式 (0.1s 采样)"

while true; do
  for f in ${TARGETS[@]}; do
    [ ! -f "$f" ] && continue
    
    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    [ -z "$ts" ] && continue
    
    old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
    old_ts=${old_ts:-0}

    if [ "$ts" -gt "$old_ts" ]; then
      ((COUNT++))

      # --- 核心原子手术 ---
      # 1. 使用极速正则删除所有干扰行
      sed -i -E "/$PATTERN/d" "$f"

      # 2. 瞬间追加全量配置块
      printf "$PAYLOAD" >> "$f"
      
      # 3. 强行冲刷磁盘缓存，确保护送给 Bazel
      sync "$f"

      # 更新数据库
      new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
      grep -v "^$f " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
      echo "$f ${new_ts:-$ts}" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"
      
      echo "::notice title=暴力劫持成功::已在 $f 完成第 $COUNT 次全量手术"
      echo "💎 [$(date +%T)] 瞬间覆盖完成：$f"
    fi
  done
  sleep 0.1
done

