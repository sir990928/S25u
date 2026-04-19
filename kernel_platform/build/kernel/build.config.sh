#!/bin/bash

# --- 核心路径指纹 ---
TARGET_PATH_A="execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
TARGET_PATH_B="execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"

# --- 手术清单 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VERSION="-SukiSU-Ultra"

# 初始化计数器和数据库
COUNT=0
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"

export stdbuf -oL
echo "🚀 [$(date +%T)] 劫持引擎点火成功！哨兵已就位..."

while true; do
  find kernel_platform/bazel-cache -type f -name ".config" 2>/dev/null | while read -r f; do
    
    if [[ "$f" == *"$TARGET_PATH_A" ]] || [[ "$f" == *"$TARGET_PATH_B" ]]; then
      ts=$(stat -c "%Y" "$f" 2>/dev/null)
      [ -z "$ts" ] && continue
      
      old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
      old_ts=${old_ts:-0}

      if [ "$ts" -gt "$old_ts" ]; then
        # 计数累加
        ((COUNT++))
        
        echo -e "\n🔔 [$(date +%T)] >>>>> 第 $COUNT 次拦截成功 <<<<<"
        echo "📍 目标文件: $f"

        # 1. 夺取写权限
        sudo chmod +w "$f" 2>/dev/null

        # --- 手术逻辑开始 ---

        # A. 版本号精准替换
        if grep -q "CONFIG_LOCALVERSION=" "$f"; then
            sudo sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"
        else
            echo "CONFIG_LOCALVERSION=\"$NEW_VERSION\"" | sudo tee -a "$f" > /dev/null
        fi

        # B. 关闭项：切除子项 + 原地替换本体
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
        
        echo "💎 [$(date +%T)] 修改成功 $COUNT 次！手术逻辑执行完毕。"
        echo "----------------------------------------------------"
      fi
    fi
  done
  sleep 0.2
done

