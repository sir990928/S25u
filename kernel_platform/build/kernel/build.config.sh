#!/bin/bash

# --- 核心指纹：沿用你成功的后缀匹配逻辑 ---
TARGET_PATH_A="execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
TARGET_PATH_B="execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"

# --- 修改配置 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VER="-SukiSU-Ultra"

TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"

# 强制输出启动心跳，方便在日志中确认脚本已运行
echo "🕵️ [$(date +%T)] 劫持引擎点火：准备捕获目标配置..."
echo "📍 监控后缀A: $TARGET_PATH_A"

while true; do
  # 这里的 find 是关键：它能穿透所有哈希文件夹，把所有的 .config 找出来
  find kernel_platform/bazel-cache -type f -name ".config" 2>/dev/null | while read -r file; do
    
    # 字符串后缀匹配（最稳的方法）
    if [[ "$file" == *"$TARGET_PATH_A" ]] || [[ "$file" == *"$TARGET_PATH_B" ]]; then
      
      ts=$(stat -c "%Y" "$file" 2>/dev/null)
      [ -z "$ts" ] && continue
      
      old_ts=$(grep "^$file " "$TIME_DB" 2>/dev/null | awk '{print $2}')
      old_ts=${old_ts:-0}

      # 判定：时间戳更新，说明 Bazel 重置了配置
      if [ "$ts" -gt "$old_ts" ]; then
        # 这一行日志如果不出来，说明权限或 find 有问题
        echo "🔥 [$(date +%T)] 拦截到配置更新: $file"

        # --- 执行精准 sed 修改 ---
        # 1. 版本号劫持
        sed -i "/CONFIG_LOCALVERSION=/d" "$file"
        echo "CONFIG_LOCALVERSION=\"$NEW_VER\"" >> "$file"

        # 2. 批量禁用安全项
        for cfg in "${CONFIGS[@]}"; do
          sed -i "/^CONFIG_${cfg}[=_ ]/d" "$file" 
          echo "# CONFIG_$cfg is not set" >> "$file"
        done

        # 3. 批量启用功能项
        for cfg in "${ENABLE[@]}"; do
          sed -i "/^CONFIG_${cfg}[=_ ]/d" "$file"
          echo "CONFIG_$cfg=y" >> "$file"
        done

        # 更新数据库
        new_ts=$(stat -c "%Y" "$file" 2>/dev/null)
        grep -v "^$file " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
        echo "$file ${new_ts:-$ts}" >> "$TIME_DB.tmp"
        mv -f "$TIME_DB.tmp" "$TIME_DB"
        
        echo "✅ [$(date +%T)] 修改完毕，已注入配置。"
      fi
    fi
  done
  
  # 稍微缩短轮询间隔，提高“一瞬间修改”的成功率
  sleep 0.4
done

