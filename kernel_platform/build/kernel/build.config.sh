#!/usr/bin/env bash

# --- 原始配置部分 (保留或根据你的需求定义) ---
# 这里通常会有 ARCH, CROSS_COMPILE 等定义，请确保它们在上面
# ------------------------------------------

# --- 自动化配置劫持哨兵 (后台异步执行) ---
(
    # 1. 定义监控的目标（支持 Bazel 动态路径通配符）
    TARGETS=(
        "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
        "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
    )

    # 2. 定义修改配置项
    CONFIGS=("KNOX_NCM" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
    ENABLE=("KSU" "KPM" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")
    NEW_VER="-SukiSU-Ultra"

    echo "🛰️ 哨兵引擎已在后台就位，开始监控 .config 状态..."

    # 3. 核心监控死循环
    while true; do
        for pattern in "${TARGETS[@]}"; do
            # 展开通配符并循环处理每一个匹配到的文件
            for f in $pattern; do
                [ ! -f "$f" ] && continue
                
                STAMP="${f}.stamp"

                # --- 时间戳增量对比逻辑 ---
                # 如果标记文件存在，且目标文件不比标记文件新（说明是我们改过的），就跳过
                if [ -f "$STAMP" ] && [ ! "$f" -nt "$STAMP" ]; then
                    continue
                fi

                echo "⚡ [$(date +%T)] 检测到 $f 更新，立即执行手术..."

                # A. 强制写入自定义版本号
                sed -i "/CONFIG_LOCALVERSION=/d" "$f"
                echo "CONFIG_LOCALVERSION=\"$NEW_VER\"" >> "$f"

                # B. 彻底切除不需要的项 (含子项处理)
                for cfg in "${CONFIGS[@]}"; do
                    # 优先删除所有以此开头的子项，防止干扰
                    sed -i "/^CONFIG_${cfg}_/d" "$f" 
                    if grep -q "CONFIG_$cfg" "$f"; then
                        sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f"
                    elif ! grep -q "# CONFIG_$cfg is not set" "$f"; then
                        echo "# CONFIG_$cfg is not set" >> "$f"
                    fi
                done

                # C. 开启性能与功能项
                for cfg in "${ENABLE[@]}"; do
                    if ! grep -q "^CONFIG_$cfg=y" "$f"; then
                        # 尝试修改现有项或取消注释，若都不存在则追加
                        if grep -q "CONFIG_$cfg" "$f" || grep -q "# CONFIG_$cfg is not set" "$f"; then
                            sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
                            sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f"
                        else
                            echo "CONFIG_$cfg=y" >> "$f"
                        fi
                    fi
                done

                # --- 同步时间戳：将 .config 的原始时间赋予 STAMP ---
                touch -r "$f" "$STAMP"
                echo "✅ [$(date +%T)] 劫持成功，等待下一次变更。"
            done
        done
        # 轮询间隔，2秒一次既能快速拦截又不会给 CPU 增加负担
        sleep 2
    done
) > /tmp/kernel_hijack.log 2>&1 & 

# --- 脚本结束，主编译进程将无阻碍继续 ---
echo "🚀 编译环境初始化完成，后台哨兵已启动。"

