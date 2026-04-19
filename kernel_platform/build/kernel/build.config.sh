#!/bin/bash

# --- 核心指纹：直接沿用你之前成功的字符串 ---
TARGET_PATH_A="execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
TARGET_PATH_B="execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"

# --- 修改配置 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")

TIME_DB=/tmp/.hijack_time_db
touch "$TIME_DB"

echo "🕵️ [$(date +%T)] 劫持引擎启动"
echo "📍 目标A: $TARGET_PATH_A"
echo "📍 目标B: $TARGET_PATH_B"

while true; do
  # 这里的 find + 字符串匹配就是你“有日志”版本的灵魂
  find kernel_platform/bazel-cache -type f -name ".config" 2>/dev/null | while read -r file; do
    
    # 只要路径字符串包含目标指纹
    if [[ "$file" == *"$TARGET_PATH_A" ]] || [[ "$file" == *"$TARGET_PATH_B" ]]; then
      
      # 时间戳逻辑
      ts=$(stat -c "%Y" "$file" 2>/dev/null)
      [ -z "$ts" ] && continue
      
      old_ts=$(grep "^$file " "$TIME_DB" 2>/dev/null | awk '{print $2}')
      old_ts=${old_ts:-0}

      if [ "$ts" -gt "$old_ts" ]; then
        echo "🔥 [$(date +%T)] 检测到更新: $file"

        # --- 开始 sed 手术 ---
        # 1. 版本号
        sed -i "/CONFIG_LOCALVERSION=/d" "$file"
        echo "CONFIG_LOCALVERSION=\"-SukiSU-Ultra\"" >> "$file"

        # 2. 禁用项
        for cfg in "${CONFIGS[@]}"; do
          sed -i "/^CONFIG_${cfg}_/d" "$file" 
          sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$file" || echo "# CONFIG_$cfg is not set" >> "$file"
        done

        # 3. 启用项
        for cfg in "${ENABLE[@]}"; do
          if ! grep -q "^CONFIG_$cfg=y" "$file"; then
            sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$file"
            sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$file" || echo "CONFIG_$cfg=y" >> "$file"
          fi
        done

        # 更新时间数据库
        new_ts=$(stat -c "%Y" "$file" 2>/dev/null)
        grep -v "^$file " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
        echo "$file ${new_ts:-$ts}" >> "$TIME_DB.tmp"
        mv -f "$TIME_DB.tmp" "$TIME_DB"
        
        echo "✅ [$(date +%T)] 已修改完毕: $file"
      fi
    fi
  done
  sleep 0.7
done

