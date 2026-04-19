#!/usr/bin/env bash

TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)
CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VER="-SukiSU-Ultra"

echo "🛰️ 哨兵已就绪，开始后台巡检..."

while true; do
    for pattern in "${TARGETS[@]}"; do
        for f in $pattern; do
            [ ! -f "$f" ] && continue
            STAMP="${f}.stamp"
            if [ -f "$STAMP" ] && [ ! "$f" -nt "$STAMP" ]; then continue; fi

            echo "⚡ [$(date +%T)] 拦截手术: $(basename "$f")"
            sed -i "/CONFIG_LOCALVERSION=/d" "$f"
            echo "CONFIG_LOCALVERSION=\"$NEW_VER\"" >> "$f"

            for cfg in "${CONFIGS[@]}"; do
                sed -i "/^CONFIG_${cfg}_/d" "$f" 
                sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f" || echo "# CONFIG_$cfg is not set" >> "$f"
            done

            for cfg in "${ENABLE[@]}"; do
                if ! grep -q "^CONFIG_$cfg=y" "$f"; then
                    sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
                    sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f" || echo "CONFIG_$cfg=y" >> "$f"
                fi
            done
            touch -r "$f" "$STAMP"
        done
    done
    sleep 2
done

