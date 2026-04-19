#!/bin/bash

# --- 1. 定点爆破：利用 * 穿透随机哈希目录 (你提供的精确坐标) ---
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 手术配置 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VERSION="-SukiSU-Ultra"

# --- 3. 初始化 (持久化计数与时间戳) ---
COUNT_FILE="/tmp/hijack_count"
echo 0 > "$COUNT_FILE"
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"

# 强制行缓冲，确保日志秒出
export stdbuf -oL

echo "🚀 [$(date +%T)] 劫持引擎点火：定点拦截模式 (0.1s 采样)"

while true; do
  # 直接遍历目标路径（通配符展开比 find 快上百倍）
  for f in ${TARGETS[@]}; do
    # 只有文件存在才处理
    [ ! -f "$f" ] && continue
    
    ts=$(stat -c "%Y" "$f" 2>/dev/null)
    [ -z "$ts" ] && continue
    
    old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
    old_ts=${old_ts:-0}

    # 判定：时间戳更新即视为 Bazel 重置了配置
    if [ "$ts" -gt "$old_ts" ]; then
      # 更新并读取计数
      curr_count=$(($(cat "$COUNT_FILE") + 1))
      echo "$curr_count" > "$COUNT_FILE"

      echo -e "\n🎯 >>>>> [$(date +%T)] 发现目标：第 $curr_count 次捕获 <<<<<"
      echo "📂 命中路径: $f"

      # 1. 强夺写权限
      sudo chmod +w "$f" 2>/dev/null

      # --- 执行精准手术逻辑 ---
      
      # A. 版本号
      if grep -q "CONFIG_LOCALVERSION=" "$f"; then
          sudo sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"
      else
          echo "CONFIG_LOCALVERSION=\"$NEW_VERSION\"" | sudo tee -a "$f" > /dev/null
      fi

      # B. 关闭项 (物理切除 PROCA_XXX + 原地替换)
      for cfg in "${CONFIGS[@]}"; do
          sudo sed -i "/^CONFIG_${cfg}_/d" "$f"
          sudo sed -i "/^# CONFIG_${cfg}_/d" "$f"
          if grep -q "CONFIG_$cfg" "$f" || grep -q "# CONFIG_$cfg is not set" "$f"; then
              sudo sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f"
              sudo sed -i "s/^# CONFIG_$cfg is not set.*/# CONFIG_$cfg is not set/" "$f"
          else
              echo "# CONFIG_$cfg is not set" | sudo tee -a "$f" > /dev/null
          fi
      done

      # C. 开启项
      for cfg in "${ENABLE[@]}"; do
          if grep -q "CONFIG_$cfg" "$f"; then
              sudo sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
              sudo sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f"
          else
              echo "CONFIG_$cfg=y" | sudo tee -a "$f" > /dev/null
          fi
      done

      # 更新数据库
      new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
      grep -v "^$f " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
      echo "$f ${new_ts:-$ts}" >> "$TIME_DB.tmp"
      mv -f "$TIME_DB.tmp" "$TIME_DB"
      
      echo "💎 [$(date +%T)] 修改成功 $curr_count 次！手术完毕。"
      echo "--------------------------------------------------------"
    fi
  done
  
  # 极速轮询：0.1s 是脚本性能的黄金平衡点
  sleep 0.1
done

