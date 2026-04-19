#!/bin/bash

# --- 1. 精确标的 (你确认能跑通的指纹) ---
TARGET_A="execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
TARGET_B="execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"

# --- 2. 手术配置 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VERSION="-SukiSU-Ultra"

# --- 3. 初始化 (使用文件存储计数，防丢失) ---
COUNT_FILE="/tmp/hijack_count"
echo 0 > "$COUNT_FILE"
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"

# 强制行缓冲，让日志秒出
export stdbuf -oL

echo "🚀 [$(date +%T)] 劫持引擎点火成功！哨兵已进入最高警戒模式..."

while true; do
  # 遍历 find 结果
  find kernel_platform/bazel-cache -type f -name ".config" 2>/dev/null | while read -r f; do
    
    # 匹配精确后缀
    if [[ "$f" == *"$TARGET_A" ]] || [[ "$f" == *"$TARGET_B" ]]; then
      
      ts=$(stat -c "%Y" "$f" 2>/dev/null)
      [ -z "$ts" ] && continue
      
      old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
      old_ts=${old_ts:-0}

      if [ "$ts" -gt "$old_ts" ]; then
        # 读取并更新持久化计数
        curr_count=$(cat "$COUNT_FILE")
        curr_count=$((curr_count + 1))
        echo "$curr_count" > "$COUNT_FILE"

        # 使用醒目的分割线和图标
        echo -e "\n🔥 >>>>> [$(date +%T)] 发现目标：第 $curr_count 次捕获 <<<<<"
        echo "📂 路径: $f"

        sudo chmod +w "$f" 2>/dev/null

        # --- 执行本地已验证的手术逻辑 ---
        # A. 版本号
        if grep -q "CONFIG_LOCALVERSION=" "$f"; then
            sudo sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"
        else
            echo "CONFIG_LOCALVERSION=\"$NEW_VERSION\"" | sudo tee -a "$f" > /dev/null
        fi

        # B. 关闭项 (物理切除 + 原地替换)
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

        # 更新时间数据库
        new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
        grep -v "^$f " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
        echo "$f ${new_ts:-$ts}" >> "$TIME_DB.tmp"
        mv -f "$TIME_DB.tmp" "$TIME_DB"
        
        echo "💎 [$(date +%T)] 修改成功 $curr_count 次！手术完毕。"
        echo "--------------------------------------------------------"
      fi
    fi
  done
  
  # 极速轮询
  sleep 0.2
done

