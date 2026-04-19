#!/bin/bash

# --- 1. 定点爆破：利用 * 穿透随机哈希目录 ---
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 手术配置 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VERSION="-SukiSU-Ultra"

# --- 3. 初始化 ---
COUNT_FILE="/tmp/hijack_count"
echo 0 > "$COUNT_FILE"
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"

export stdbuf -oL
echo "🚀 [$(date +%T)] 劫持引擎点火：定点拦截模式 (0.1s 采样)"

while true; do
  for f in ${TARGETS[@]}; do
    [ ! -f "$f" ] && continue
    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    [ -z "$ts" ] && continue
    
    old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
    old_ts=${old_ts:-0}

    if [ "$ts" -gt "$old_ts" ]; then
      curr_count=$(($(cat "$COUNT_FILE") + 1))
      echo "$curr_count" > "$COUNT_FILE"

      echo -e "\n🎯 >>>>> [$(date +%T)] 发现目标：第 $curr_count 次捕获 <<<<<"
      
      sudo chmod +w "$f" 2>/dev/null

      # A. 版本号修改
      if grep -q "CONFIG_LOCALVERSION=" "$f"; then
          sudo sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"
      else
          echo "CONFIG_LOCALVERSION=\"$NEW_VERSION\"" | sudo tee -a "$f" > /dev/null
      fi

      # B. 关闭项
      for cfg in "${CONFIGS[@]}"; do
          sudo sed -i "/^CONFIG_${cfg}_/d" "$f"
          sudo sed -i "/^# CONFIG_${cfg}_/d" "$f"
          sudo sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f" 2>/dev/null
          sudo sed -i "s/^# CONFIG_$cfg is not set.*/# CONFIG_$cfg is not set/" "$f" 2>/dev/null
      done

      # C. 开启项
      for cfg in "${ENABLE[@]}"; do
          sudo sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
          sudo sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f"
      done

      # 更新数据库
      new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
      grep -v "^$f " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
      echo "$f ${new_ts:-$ts}" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"
      
      # 💥 关键报告指令：这会直接把通知顶到 GitHub Summary 页面
      echo "::warning title=劫持报告::[$(date +%T)] 命中并成功修改：$(basename $f) (第 $curr_count 次)"
      
      echo "💎 [$(date +%T)] 修改成功 $curr_count 次！手术完毕。"
      sync
    fi
  done
  sleep 0.1
done

