#!/usr/bin/env bash

# 定义监控的目标（支持通配符）
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VER="-SukiSU-Ultra"

echo "🛰️ 哨兵引擎已就绪，开始实时监控..."

# --- 关键：外层死循环 ---
while true; do
    for pattern in "${TARGETS[@]}"; do
        for f in $pattern; do
            [ ! -f "$f" ] && continue
            
            STAMP="${f}.stamp"

            # 时间戳比对：如果 .config 不比标记文件新，说明是我们改过的，跳过
            if [ -f "$STAMP" ] && [ ! "$f" -nt "$STAMP" ]; then
                continue
            fi

            echo "⚡ [$(date +%T)] 发现更新/重置: $(basename "$f")"

            # 1. 强制版本号
            sed -i "/CONFIG_LOCALVERSION=/d" "$f"
            echo "CONFIG_LOCALVERSION=\"$NEW_VER\"" >> "$f"

            # 2. 彻底切除关闭项 (含子项)
            for cfg in "${CONFIGS[@]}"; do
                sed -i "/^CONFIG_${cfg}_/d" "$f" 
                if grep -q "CONFIG_$cfg" "$f"; then
                    sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f"
                elif ! grep -q "# CONFIG_$cfg is not set" "$f"; then
                    echo "# CONFIG_$cfg is not set" >> "$f"
                fi
            done

            # 3. 开启性能项
            for cfg in "${ENABLE[@]}"; do
                if ! grep -q "^CONFIG_$cfg=y" "$f"; then
                    sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
                    sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f" || echo "CONFIG_$cfg=y" >> "$f"
                fi
            done

            # 同步时间戳
            touch -r "$f" "$STAMP"
            echo "✅ 手术成功，时间戳已同步。"
        done
    done
    # 稍微休息，避免过度占用 CPU
    sleep 2
done

