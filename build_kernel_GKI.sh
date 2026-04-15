#!/bin/bash

# 1. 合并分片
echo "🔧 合并分片文件..."
find . -name "*.part.aa" | while read -r part; do
    original="${part%.part.aa}"
    cat "$original".part.a* > "$original"
    rm -f "$original".part.*
    echo "✅ 已合并：$original"
done

# 1.1. 暴力赋权 (关键：必须在合并后)
chmod -R 777 ./kernel_platform/prebuilts

# 1. target config
BUILD_TARGET=$1
export MODEL=$(echo $BUILD_TARGET | cut -d'_' -f1)
export PROJECT_NAME=${MODEL}
export REGION=$(echo $BUILD_TARGET | cut -d'_' -f2)
export CARRIER=$(echo $BUILD_TARGET | cut -d'_' -f3)
export TARGET_BUILD_VARIANT=$2

# 2. sm8650 common config
CHIPSET_NAME=$3
# 自定义 defconfig（第四个参数，不传则默认 s25_gki_defconfig）
export USER_DEFCONFIG=${4:-s25_gki_defconfig}

export ANDROID_BUILD_TOP=$(pwd)
export TARGET_PRODUCT=perf
export TARGET_BOARD_PLATFORM=gki

# 强制使用你指定的 defconfig
export KERNEL_DEFCONFIG=${USER_DEFCONFIG}
# 不加载任何额外碎片，完全只用你自己的完整config
export KERNEL_FRAGMENTS=""

export ANDROID_PRODUCT_OUT=${ANDROID_BUILD_TOP}/out/target/product/${MODEL}
export OUT_DIR=${ANDROID_BUILD_TOP}/out/msm-${CHIPSET_NAME}-${CHIPSET_NAME}-${TARGET_PRODUCT}

# for Lcd(techpack) driver build
export KBUILD_EXTRA_SYMBOLS=${ANDROID_BUILD_TOP}/out/vendor/qcom/opensource/mmrm-driver/Module.symvers

# for Audio(techpack) driver build
export MODNAME=audio_dlkm

export KBUILD_EXT_MODULES="\
	../vendor/qcom/opensource/mmrm-driver \
        ../vendor/qcom/opensource/mm-drivers/msm_ext_display \
        ../vendor/qcom/opensource/mm-drivers/sync_fence \
        ../vendor/qcom/opensource/mm-drivers/hw_fence \
        ../vendor/qcom/opensource/securemsm-kernel \
        "

# 3. build kernel
cd ./kernel_platform/
echo "✅ 使用内核配置：${KERNEL_DEFCONFIG}"
echo "✅ 已禁用额外config碎片，仅使用你自身完整配置"
RECOMPILE_KERNEL=1 ./build/android/prepare_vendor.sh ${CHIPSET_NAME} ${TARGET_PRODUCT} gki | tee -a ../build.log

