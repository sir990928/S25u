#!/usr/bin/env bash

# 定义监控的目标（支持通配符）
TARGETS=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
NEW_VER="-SukiSU-Ultra"

# 展开通配符并循环
for pattern in "${TARGETS[@]}"; do
    for f in $pattern; do
        [ ! -f "$f" ] && continue
        
        STAMP="${f}.stamp"

        # --- 核心：时间戳对比逻辑 ---
        # 如果标记文件存在，且目标文件不比标记文件新（说明是我们改过的），就跳过
        if [ -f "$STAMP" ] && [ ! "$f" -nt "$STAMP" ]; then
            continue
        fi

        echo "⚡ 发现新生成或被重置的文件: $(basename "$f")"

        # 1. 强制版本号
        sed -i "/CONFIG_LOCALVERSION=/d" "$f"
        echo "CONFIG_LOCALVERSION=\"$NEW_VER\"" >> "$f"

        # 2. 彻底切除关闭项 (含子项)
        for cfg in "${CONFIGS[@]}"; do
            if grep -q "^CONFIG_${cfg}" "$f"; then
                sed -i "/^CONFIG_${cfg}_/d" "$f" 
                sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f"
            elif ! grep -q "# CONFIG_$cfg is not set" "$f"; then
                echo "# CONFIG_$cfg is not set" >> "$f"
            fi
        done

        # 3. 开启性能项
        for cfg in "${ENABLE[@]}"; do
            if ! grep -q "^CONFIG_$cfg=y" "$f"; then
                if grep -q "CONFIG_$cfg" "$f" || grep -q "# CONFIG_$cfg is not set" "$f"; then
                    sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
                    sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f"
                else
                    echo "CONFIG_$cfg=y" >> "$f"
                fi
            fi
        done

        # --- 同步时间戳：让 STAMP 的修改时间完全等于 .config ---
        touch -r "$f" "$STAMP"
        echo "✅ 手术成功，时间戳已锁定。"
    done
done

