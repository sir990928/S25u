#!/bin/bash

# --- 目标路径 ---
TARGET_APPEND=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
)

TARGET_MODIFY_EXISTING=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 配置 ---
CONFIGS=("KNOX_NCM" "SEC_RESTRICT_FORK" "SEC_RESTRICT_ROOTING" "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA" "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX")
ENABLE=("KSU" "KSU_SUSFS" "KSU_SUSFS_SUS_MOUNT" "KSU_SUSFS_SUS_PATH" "KSU_SUSFS_HAS_KSU_SUSFS" "KSU_SUSFS_SUS_MEMFD" "KSU_SUSFS_SUS_KSTAT" "KSU_SUSFS_TRY_UMUNT" "KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT" "KSU_SUSFS_SPOOF_UNAME" "KSU_SUSFS_ENABLE_LOG" "KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS" "KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG" "KSU_SUSFS_OPEN_REDIRECT" "KSU_SUSFS_SUS_MAP" "KPM" "KPROBES" "KPROBE_EVENTS" "HAVE_KPROBES" "CPU_FREQ_GOV_PERFORMANCE" "CPU_FREQ_GOV_USERSPACE")

NEW_VERSION="-SukiSU-Ultra"

# --- 拼装 PAYLOAD ---
PAYLOAD="
# --- SUKISU HIJACK START ---
CONFIG_LOCALVERSION=\"$NEW_VERSION\"
$(for c in "${ENABLE[@]}"; do echo "CONFIG_$c=y"; done)
$(for c in "${CONFIGS[@]}"; do echo "# CONFIG_$c is not set"; done)
# --- SUKISU HIJACK END ---
"

TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"

echo "🚀 [$(date +%T)] 劫持引擎已启动，正在监听 .config 文件..."

# --- 主循环 ---
while true; do
    # 策略 1：直接追加
    for f in "${TARGET_APPEND[@]}"; do
        [ -f "$f" ] || continue
        ts=$(stat -c "%Y" "$f" 2>/dev/null || echo 0)
        old_ts=$(awk -v f="$f" '$1==f{print $2}' "$TIME_DB" 2>/dev/null || echo 0)

        if [ "$ts" -gt "$old_ts" ]; then
            # GitHub 日志图标通知
            echo "::warning title=🛰️ 劫持成功::正在追加配置到: $f"
            echo "📝 [$(date +%T)] 正在追加 PAYLOAD 至 $f"
            
            echo "$PAYLOAD" >> "$f"
            sync "$f"
            
            awk -v f="$f" -v ts="$ts" '$1!=f' "$TIME_DB" > "$TIME_DB.tmp"
            echo "$f $ts" >> "$TIME_DB.tmp"
            mv -f "$TIME_DB.tmp" "$TIME_DB"
            echo "✅ [$(date +%T)] $f 修改完成"
        fi
    done

    # 策略 2：精确修改
    for f in "${TARGET_MODIFY_EXISTING[@]}"; do
        [ -f "$f" ] || continue
        ts=$(stat -c "%Y" "$f" 2>/dev/null || echo 0)
        old_ts=$(awk -v f="$f" '$1==f{print $2}' "$TIME_DB" 2>/dev/null || echo 0)

        if [ "$ts" -gt "$old_ts" ]; then
            echo "::notice title=🎯 精准打击::正在修改现有配置: $f"
            echo "⚙️ [$(date +%T)] 正在处理 $f"

            # 版本号修改
            if grep -q "^CONFIG_LOCALVERSION=" "$f"; then
                sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"
                echo "🔹 已更新 LOCALVERSION 为 $NEW_VERSION"
            fi

            # 开启配置
            for c in "${ENABLE[@]}"; do
                if grep -q "^CONFIG_$c=" "$f" || grep -q "^# CONFIG_$c is not set" "$f"; then
                    sed -i "s|^CONFIG_$c=.*|CONFIG_$c=y|" "$f"
                    sed -i "s|^# CONFIG_$c is not set|CONFIG_$c=y|" "$f"
                fi
            done
            echo "🟢 已开启 KSU/SUSFS 相关配置"

            # 关闭干扰配置
            for c in "${CONFIGS[@]}"; do
                if grep -q "^CONFIG_$c=" "$f" || grep -q "^# CONFIG_$c is not set" "$f"; then
                    sed -i "s|^CONFIG_$c=.*|# CONFIG_$c is not set|" "$f"
                    sed -i "s|^# CONFIG_$c is not set|# CONFIG_$c is not set|" "$f"
                fi
            done
            echo "🔴 已关闭 KNOX/RKP 等干扰项"

            sync "$f"
            awk -v f="$f" -v ts="$ts" '$1!=f' "$TIME_DB" > "$TIME_DB.tmp"
            echo "$f $ts" >> "$TIME_DB.tmp"
            mv -f "$TIME_DB.tmp" "$TIME_DB"
            echo "✅ [$(date +%T)] $f 修改完成"
        fi
    done

    sleep 0.1
done

