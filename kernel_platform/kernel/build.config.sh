#!/data/data/com.termux/files/usr/bin/bash

file1="/sdcard/Download/AGC/kernel_aarch64_dot_config"
file2="/sdcard/Download/AGC/sun_perf_dot_config"

# 需要关闭的配置（删除 XXX_* 并设为 is not set）
CONFIGS=(
    "KNOX_NCM"
    "UH"
    "RKP"
    "KDP"
    "LOCALVERSION_AUTO"
    "GAF"
    "FIVE"
    "PROCA"
    "INTEGRITY"
    "TRIM_UNUSED_KSYMS"
    "SECURITY_DEFEX"
)

# 需要开启的配置
ENABLE=(
    "KSU"
    "KPM"
    "CPU_FREQ_GOV_ONDEMAND"
    "CPU_FREQ_GOV_USERSPACE"
)

# 你要改的版本号
NEW_VERSION="-SukiSU-Ultra"

for f in "$file1" "$file2"; do
    # 备份
    [ -f "$f" ] && cp "$f" "$f.bak"

    # 关闭配置
    for cfg in "${CONFIGS[@]}"; do
        # 删除所有 CONFIG_XXX_* 子配置
        sed -i "/^CONFIG_${cfg}_/d" "$f"
        # 统一设为禁用
        sed -i "s/^CONFIG_$cfg=.*/# CONFIG_$cfg is not set/" "$f"
    done

    # 开启配置
    for cfg in "${ENABLE[@]}"; do
        sed -i "s/^# CONFIG_$cfg is not set/CONFIG_$cfg=y/" "$f"
        sed -i "s/^CONFIG_$cfg=.*/CONFIG_$cfg=y/" "$f"
    done

    # 修改版本号
    sed -i "s|^CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION=\"$NEW_VERSION\"|" "$f"

    echo "✅ 处理完成：$f"
done

echo -e "\n🎉 全部处理完成！"

