#!/bin/bash

# --- 1. 分路径目标 ---
TARGET_APPEND=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/common/kernel_aarch64_config/out_dir/.config"
)

TARGET_MODIFY_ONLY=(
    "kernel_platform/bazel-cache/*/execroot/_main/bazel-out/k8-fastbuild/bin/msm-kernel/sun_perf_config/out_dir/.config"
)

# --- 2. 配置清单 ---
CONFIGS=(
    "KNOX_NCM" "SEC_RESTRICT_FORK" "SEC_RESTRICT_ROOTING"
    "UH" "RKP" "KDP" "LOCALVERSION_AUTO" "GAF" "FIVE" "PROCA"
    "INTEGRITY" "TRIM_UNUSED_KSYMS" "SECURITY_DEFEX"
)

ENABLE=(
    "KSU" 
    "KSU_SUSFS" 
    "KSU_SUSFS_SUS_MOUNT" 
    "KSU_SUSFS_SUS_PATH" 
    "KSU_SUSFS_HAS_KSU_SUSFS" 
    "KSU_SUSFS_SUS_MEMFD" 
    "KSU_SUSFS_SUS_KSTAT" 
    "KSU_SUSFS_TRY_UMUNT" 
    "KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT" 
    "KSU_SUSFS_SPOOF_UNAME" 
    "KSU_SUSFS_ENABLE_LOG" 
    "KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS" 
    "KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG" 
    "KSU_SUSFS_OPEN_REDIRECT" 
    "KSU_SUSFS_SUS_MAP" 
    "KPM" 
    "KPROBES" 
    "KPROBE_EVENTS" 
    "HAVE_KPROBES" 
    "CPU_FREQ_GOV_PERFORMANCE" 
    "CPU_FREQ_GOV_USERSPACE"
)

NEW_VERSION="-SukiSU-Ultra"

# --- 3. 数据库 ---
TIME_DB="/tmp/.hijack_time_db"
touch "$TIME_DB"
COUNT=0

# 追加用的完整块
PAYLOAD=$(cat <<EOF

# --- SUKISU HIJACK FINAL OVERRIDE ---
CONFIG_LOCALVERSION="${NEW_VERSION}"
$(for c in "${ENABLE[@]}"; do echo "CONFIG_$c=y"; done)
$(for c in "${CONFIGS[@]}"; do echo "# CONFIG_$c is not set"; done)
# --- END SUKISU ---
EOF
)

echo "🚀 [$(date +%T)] 双模式：路径1追加，路径2仅修改"

while true; do
    # --------------------------
    # 第一类：整段追加
    # --------------------------
    for f in "${TARGET_APPEND[@]}"; do
        [ -f "$f" ] || continue
        ts=$(stat -c "%Y" "$f" 2>/dev/null)
        [ -z "$ts" ] && continue
        old_ts=$(awk -v f="$f" '$1==f{print $2}' "$TIME_DB" 2>/dev/null)
        old_ts=${old_ts:-0}

        if [ "$ts" -gt "$old_ts" ]; then
            ((COUNT++))
            echo "$PAYLOAD" >> "$f"
            sync "$f"
            awk -v f="$f" -v ts="$ts" '$1!=f' "$TIME_DB" > "$TIME_DB.tmp"
            echo "$f $ts" >> "$TIME_DB.tmp"
            mv -f "$TIME_DB.tmp" "$TIME_DB"
            echo "::notice title=已追加::$f"
        fi
    done

    # --------------------------
    # 第二类：只修改已有项，不追加
    # --------------------------
    for f in "${TARGET_MODIFY_ONLY[@]}"; do
        [ -f "$f" ] || continue
        ts=$(stat -c "%Y" "$f" 2>/dev/null)
        [ -z "$ts" ] && continue
        old_ts=$(awk -v f="$f" '$1==f{print $2}' "$TIME_DB" 2>/dev/null)
        old_ts=${old_ts:-0}

        if [ "$ts" -gt "$old_ts" ]; then
            ((COUNT++))

            # 版本号
            sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"

            # 开启项：只替换已有的
            for c in "${ENABLE[@]}"; do
                sed -i "s|^CONFIG_$c=.*|CONFIG_$c=y|" "$f"
            done

            # 关闭项：只替换已有的
            for c in "${CONFIGS[@]}"; do
                sed -i "s|^CONFIG_$c=.*|# CONFIG_$c is not set|" "$f"
            done

            sync "$f"
            awk -v f="$f" -v ts="$ts" '$1!=f' "$TIME_DB" > "$TIME_DB.tmp"
            echo "$f $ts" >> "$TIME_DB.tmp"
            mv -f "$TIME_DB.tmp" "$TIME_DB"
            echo "::notice title=仅修改已有配置::$f"
        fi
    done

    sleep 0.1
done

