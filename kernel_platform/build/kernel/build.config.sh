#!/bin/bash

# --- 1. 目标路径定义 ---
# 策略 A：直接追加 (通用 GKI 配置)
TARGET_APPEND=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
)

# 策略 B：精准修改 (三星专用配置，支持 y 变禁用)
TARGET_MODIFY=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 手术配置清单 ---
# 需要关闭/禁用的项 (y -> # CONFIG_XXX is not set)
CONFIGS=("KNOX_NCM" "SEC_RESTRICT_FORK" "SEC_RESTRICT_ROOTING" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")

# 需要开启的项 (is not set -> y)
ENABLE=("KSU" "KSU_SUSFS" "KSU_SUSFS_SUS_MOUNT" "KSU_SUSFS_SUS_PATH" "KSU_SUSFS_HAS_KSU_SUSFS" "KSU_SUSFS_SUS_MEMFD" "KSU_SUSFS_SUS_KSTAT" "KSU_SUSFS_TRY_UMUNT" "KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT" "KSU_SUSFS_SPOOF_UNAME" "KSU_SUSFS_ENABLE_LOG" "KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS" "KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG" "KSU_SUSFS_OPEN_REDIRECT" "KSU_SUSFS_SUS_MAP" "KPM" "KPROBES" "KPROBE_EVENTS" "HAVE_KPROBES" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")

# 内核 LocalVersion 后缀
NEW_VERSION="-SukiSU-Ultra"

# --- 3. 引擎逻辑处理 ---
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"
COUNT=0

# 预构建追加用的 PAYLOAD
PAYLOAD=$(cat <<EOF

# --- SUKISU HIJACK OVERRIDE START ---
CONFIG_LOCALVERSION="${NEW_VERSION}"
$(for c in "${ENABLE[@]}"; do echo "CONFIG_$c=y"; done)
$(for c in "${CONFIGS[@]}"; do echo "# CONFIG_$c is not set"; done)
# --- SUKISU HIJACK OVERRIDE END ---
EOF
)

echo "🔥 [$(date +%T)] 劫持引擎全功率启动！"
echo "📡 正在监听 A 组 (追加覆盖) 和 B 组 (手术改写)..."

while true; do
  # ======================================
  # 策略 A：追加覆盖 (确保优先级最高)
  # ======================================
  for f in ${TARGET_APPEND[@]}; do
    [ ! -f "$f" ] && continue
    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    old_ts=$(awk -v f="$f" '$1==f{print $2}' "$TIME_DB" 2>/dev/null || echo 0)

    # 只要时间戳更新，或者发现被 Bazel 还原了内容，就立刻补刀
    if [ "$ts" -gt "$old_ts" ] || ! grep -q "SUKISU HIJACK" "$f"; then
      ((COUNT++))
      echo "$PAYLOAD" >> "$f"
      sync "$f"
      
      echo "::warning title=🛰️ 策略A·追加注入::[$COUNT] 已改写: $f"
      awk -v f="$f" -v ts="$ts" '$1!=f' "$TIME_DB" > "$TIME_DB.tmp"
      echo "$f $ts" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"
    fi
  done

  # ======================================
  # 策略 B：精准原位修改 (改名 + 双向改写)
  # ======================================
  for f in ${TARGET_MODIFY[@]}; do
    [ ! -f "$f" ] && continue
    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    old_ts=$(awk -v f="$f" '$1==f{print $2}' "$TIME_DB" 2>/dev/null || echo 0)

    if [ "$ts" -gt "$old_ts" ]; then
      ((COUNT++))
      echo "::notice title=🎯 策略B·精准手术::正在同步配置表: $f"

      # 1. 内核名字原位手术
      if grep -q "^CONFIG_LOCALVERSION=" "$f"; then
          sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"
          echo "🔹 [$(date +%T)] 内核名已更正: $NEW_VERSION"
      fi

      # 2. 开启目标 (y 保持 y, is not set 变 y)
      for c in "${ENABLE[@]}"; do
        sed -i "s|^CONFIG_$c=.*|CONFIG_$c=y|" "$f"
        sed -i "s|^# CONFIG_$c is not set|CONFIG_$c=y|" "$f"
      done
      echo "🟢 [$(date +%T)] 核心功能已激活"

      # 3. 禁用目标 (y 变 is not set, n 变 is not set)
      for c in "${CONFIGS[@]}"; do
        # 匹配任何形式的开启或禁用，强制统一为注释格式
        sed -i "s|^CONFIG_$c=.*|# CONFIG_$c is not set|" "$f"
        sed -i "s|^# CONFIG_$c is not set|# CONFIG_$c is not set|" "$f"
      done
      echo "🔴 [$(date +%T)] 安全干扰项已屏蔽"

      sync "$f"
      awk -v f="$f" -v ts="$ts" '$1!=f' "$TIME_DB" > "$TIME_DB.tmp"
      echo "$f $ts" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"
      echo "✅ [$(date +%T)] B组配置手术成功"
    fi
  done

  # 保持 0.1 秒高频扫描，确保存储同步
  sleep 0.1
done

