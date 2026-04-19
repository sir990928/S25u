#!/bin/bash

# --- 精确标的路径指纹 ---
TARGET_PATH_A="execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
TARGET_PATH_B="execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"

# --- 配置项 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VER="-SukiSU-Ultra"

TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"

# 强制开启行缓冲输出
export stdbuf -oL

echo "🕵️ [$(date +%T)] 实时劫持引擎点火：最高警戒模式"
echo "📍 目标指纹: $TARGET_PATH_A"

while true; do
  # 穿透哈希目录寻找 .config
  find kernel_platform/bazel-cache -type f -name ".config" 2>/dev/null | while read -r file; do
    
    # 精确后缀匹配
    if [[ "$file" == *"$TARGET_PATH_A" ]] || [[ "$file" == *"$TARGET_PATH_B" ]]; then
      
      ts=$(stat -c "%Y" "$file" 2>/dev/null)
      [ -z "$ts" ] && continue
      
      old_ts=$(grep "^$file " "$TIME_DB" 2>/dev/null | awk '{print $2}')
      old_ts=${old_ts:-0}

      # 判定：一旦文件被 Bazel 更新，立即手术
      if [ "$ts" -gt "$old_ts" ]; then
        # 立即输出日志，确保 GitHub Actions 可见
        echo "🔥 [$(date +%T)] 拦截成功: $file"

        # 1. 强行夺取修改权限并删除旧版本号
        sudo chmod +w "$file" 2>/dev/null
        sudo sed -i "/CONFIG_LOCALVERSION=/d" "$file"
        
        # 2. 注入新版本号和配置
        {
          echo "CONFIG_LOCALVERSION=\"$NEW_VER\""
          for cfg in "${CONFIGS[@]}"; do
            echo "# CONFIG_$cfg is not set"
          done
          for cfg in "${ENABLE[@]}"; do
            echo "CONFIG_$cfg=y"
          done
        } | sudo tee -a "$file" > /dev/null

        # 3. 清理掉文件中可能存在的重复项（保持配置整洁）
        for cfg in "${CONFIGS[@]}" "${ENABLE[@]}"; do
            sudo sed -i "0,/^CONFIG_${cfg}[=_ ]/! {/^CONFIG_${cfg}[=_ ]/d}" "$file" 2>/dev/null
        done

        # 更新数据库
        new_ts=$(stat -c "%Y" "$file" 2>/dev/null)
        grep -v "^$file " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
        echo "$file ${new_ts:-$ts}" >> "$TIME_DB.tmp"
        mv -f "$TIME_DB.tmp" "$TIME_DB"
        
        echo "✅ [$(date +%T)] 手术完毕，配置已强制同步。"
      fi
    fi
  done
  
  # 极短延迟 (0.1s)，实现“一瞬间修改”
  sleep 0.1
done

