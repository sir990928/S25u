#!/bin/bash

# --- 定位指纹：你指定的精确路径 ---
PATH_A="execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
PATH_B="execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"

CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VER="-SukiSU-Ultra"

echo "🕵️ [SENTINEL] 引擎已满载，等待 Bazel 露头..."

# 确保安装了监控工具
if ! command -v inotifywait &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y inotify-tools
fi

# 监听 bazel-cache 目录下所有的文件关闭写入事件
# 只要 Bazel 写完 .config，我们立刻被内核唤醒
inotifywait -r -m kernel_platform/bazel-cache -e close_write --format '%w%f' | while read -r f; do
    
    # 路径匹配校验
    if [[ "$f" == *"$PATH_A" ]] || [[ "$f" == *"$PATH_B" ]]; then
        echo "🔥 [$(date +%T)] 毫秒级拦截: $f"

        # --- 注入修改逻辑 ---
        # 劫持版本号
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

        echo "✅ [$(date +%T)] 劫持完成，内核将读取新配置"
    fi
done

