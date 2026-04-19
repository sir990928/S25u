#!/bin/bash

# --- 定位指纹：你指定的两个精确路径 ---
PATH_A="common/kernel_aarch64_config/out_dir/.config"
PATH_B="msm-kernel/sun_perf_config/out_dir/.config"

# --- 修改项配置 ---
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VER="-SukiSU-Ultra"

# 记录手术状态的数据库
TIME_DB="/tmp/.hijack_db"
touch "$TIME_DB"

echo "🕵️ [SENTINEL] 劫持引擎已点火，正在监控指定路径..."

while true; do
    # 1. 动态搜寻所有 .config
    find kernel_platform/bazel-cache -type f -name ".config" 2>/dev/null | while read -r f; do
        
        # 2. 只有匹配你指定的两个路径后缀才动手
        if [[ "$f" == *"$PATH_A" ]] || [[ "$f" == *"$PATH_B" ]]; then
            
            # 3. 时间戳对比：判断 Bazel 是否重置了文件
            current_ts=$(stat -c "%Y" "$f" 2>/dev/null)
            [ -z "$current_ts" ] && continue
            
            old_ts=$(grep "^$f " "$TIME_DB" 2>/dev/null | awk '{print $2}')
            old_ts=${old_ts:-0}

            if [ "$current_ts" -gt "$old_ts" ]; then
                echo "🔥 [$(date +%T)] 拦截到目标重置: $f"

                # --- 注入修改逻辑 ---
                # 版本号劫持
                sed -i "/CONFIG_LOCALVERSION=/d" "$f"
                echo "CONFIG_LOCALVERSION=\"$NEW_VER\"" >> "$f"

                # 禁用安全项
                for cfg in "${CONFIGS[@]}"; do
                    sed -i "/^CONFIG_${cfg}_/d" "$f" 
                    if grep -q "CONFIG_$cfg" "$f"; then
                        sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f"
                    elif ! grep -q "# CONFIG_$cfg is not set" "$f"; then
                        echo "# CONFIG_$cfg is not set" >> "$f"
                    fi
                done

                # 开启功能项
                for cfg in "${ENABLE[@]}"; do
                    if ! grep -q "^CONFIG_$cfg=y" "$f"; then
                        sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
                        sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f" || echo "CONFIG_$cfg=y" >> "$f"
                    fi
                done

                # 4. 更新数据库，记录这次手术的时间
                new_ts=$(stat -c "%Y" "$f" 2>/dev/null)
                grep -v "^$f " "$TIME_DB" > "$TIME_DB.tmp" 2>/dev/null || true
                echo "$f ${new_ts:-$current_ts}" >> "$TIME_DB.tmp"
                mv -f "$TIME_DB.tmp" "$TIME_DB"
                
                echo "✅ [$(date +%T)] 手术完毕：$f"
            fi
        fi
    done
    
    # 0.5秒高频轮询
    sleep 0.5
done

