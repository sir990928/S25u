#!/bin/bash

# --- 1. 定点爆破：穿透随机哈希目录 ---
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 手术清单 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KSU_SUSFS" "KSU_SUSFS_SUS_MOUNT" "KSU_SUSFS_SUS_PATH" "KSU_SUSFS_HAS_KSU_SUSFS" "KSU_SUSFS_SUS_MEMFD" "KSU_SUSFS_SUS_KSTAT" "KSU_SUSFS_TRY_UMUNT" "KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT" "KPM" "KPROBES" "KPROBE_EVENTS" "HAVE_KPROBES" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VERSION="-SukiSU-Ultra"

# 初始化数据库
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"
COUNT=0

# 强制行缓冲
export stdbuf -oL

echo "🚀 [$(date +%T)] 劫持引擎点火：定点拦截模式 (0.1s 采样)"

while true; do
  # 遍历目标路径（通配符展开）
  for f in ${TARGETS[@]}; do
    [ ! -f "$f" ] && continue
    
    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    [ -z "$ts" ] && continue
    
    old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
    old_ts=${old_ts:-0}

    # 判定：时间戳更新即视为 Bazel 重置了配置
    if [ "$ts" -gt "$old_ts" ]; then
      ((COUNT++))

      # A. 版本号精准替换
      if grep -q "CONFIG_LOCALVERSION=" "$f"; then
          sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"
      else
          echo "CONFIG_LOCALVERSION=\"$NEW_VERSION\"" >> "$f"
      fi

      # B. 关闭项：物理切除子项 + 原地替换本体
      for cfg in "${CONFIGS[@]}"; do
          sed -i "/^CONFIG_${cfg}_/d" "$f"
          sed -i "/^# CONFIG_${cfg}_/d" "$f"
          if grep -q "CONFIG_$cfg" "$f" || grep -q "# CONFIG_$cfg is not set" "$f"; then
              sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f"
              sed -i "s/^# CONFIG_$cfg is not set.*/# CONFIG_$cfg is not set/" "$f"
          else
              echo "# CONFIG_$cfg is not set" >> "$f"
          fi
      done

      # C. 开启项
      for cfg in "${ENABLE[@]}"; do
          if grep -q "CONFIG_$cfg" "$f"; then
              sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
              sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f"
          else
              echo "CONFIG_$cfg=y" >> "$f"
          fi
      done

      # 更新数据库
      new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
      grep -v "^$f " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
      echo "$f ${new_ts:-$ts}" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"
      
      # 💥 核心：双路报告 (网页通知 + 终端喷射)
      echo "::notice title=劫持成功::已在 $f 完成第 $COUNT 次手术"
      echo "💎 [$(date +%T)] 修改成功 $COUNT 次：$f"
      sync
    fi
  done
  sleep 0.1
done

