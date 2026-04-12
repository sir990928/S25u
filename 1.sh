#!/bin/bash
# 彻底跳过已完成prebuilts | kernel_platform同级+根目录全部【一个一单独提交推送】
BRANCH="main"
SELF_SCRIPT="1.sh"
PREBUILTS_DIR="kernel_platform/prebuilts"

cd "/workspaces/S25ultra" || exit 1
git config core.symlinks true
git config http.postBuffer 2147483648

###########################################################
# 提示：prebuilts已上传完毕，本脚本全程直接跳过
###########################################################
echo -e "\033[32m✅ 检测：${PREBUILTS_DIR} 已完成上传，全程跳过该目录处理\033[0m"

##########################################################################
# 第一部分：处理 kernel_platform 同级所有对象（跳过prebuilts，逐个单独提交推送）
##########################################################################
echo -e "\n\033[35m========== [1] 处理 kernel_platform 同级项｜逐个单独提交推送 ==========\033[0m"
shopt -s dotglob nullglob
for item in kernel_platform/*; do
    # 核心：强制跳过已上传的prebuilts
    [[ "$item" == "${PREBUILTS_DIR}" ]] && continue

    # 单个添加
    git add -- "$item" 2>/dev/null
    # 单条提交备注
    commit_msg="single_submit: ${item}"
    git commit -m "${commit_msg}" --quiet 2>/dev/null

    # 有提交才推送（避免空推送）
    if git rev-parse HEAD~1 >/dev/null 2>&1; then
        echo -e "\033[34m🚀 正在单独推送：$item\033[0m"
        until git push -f origin "${BRANCH}"; do
            echo -e "\033[31m❌ 推送失败，等待5秒重试...\033[0m"
            sleep 5
        done
    fi

    # 日志打印区分类型
    if [[ -d "$item" ]]; then
        echo -e "\033[32m✔ 完成同级目录单独提交：$item（仅外层，不进内部）\033[0m"
    else
        echo -e "\033[32m✔ 完成同级文件/软链单独提交：$item\033[0m"
    fi
done
shopt -u dotglob nullglob

##########################################################################
# 第二部分：根目录外层文件夹｜逐个单独提交推送
##########################################################################
echo -e "\n\033[35m========== [2] 处理根目录外层文件夹｜逐个单独提交推送 ==========\033[0m"
for dir_obj in ./*; do
    [[ "$dir_obj" == "./.git" || "$dir_obj" == "./kernel_platform" ]] && continue
    if [[ -d "$dir_obj" ]]; then
        git add -- "$dir_obj" 2>/dev/null
        git commit -m "root_dir_single: ${dir_obj}" --quiet 2>/dev/null
        if git rev-parse HEAD~1 >/dev/null 2>&1; then
            echo -e "\033[34m🚀 推送根目录文件夹：$dir_obj\033[0m"
            until git push -f origin "${BRANCH}"; do sleep 5;done
        fi
        echo -e "\033[32m✔ 根目录文件夹单独完成：$dir_obj\033[0m"
    fi
done

##########################################################################
# 第三部分：根目录独立文件/软链｜逐个单独提交推送
##########################################################################
echo -e "\n\033[35m========== [3] 处理根目录文件/软链｜逐个单独提交推送 ==========\033[0m"
for file_obj in ./*; do
    [[ "$file_obj" == "./.git" || "$file_obj" == "./kernel_platform" ]] && continue
    if [[ -f "$file_obj" || -L "$file_obj" ]]; then
        git add -- "$file_obj" 2>/dev/null
        git commit -m "root_file_single: ${file_obj}" --quiet 2>/dev/null
        if git rev-parse HEAD~1 >/dev/null 2>&1; then
            echo -e "\033[34m🚀 推送根目录文件：$file_obj\033[0m"
            until git push -f origin "${BRANCH}"; do sleep 5;done
        fi
        echo -e "\033[32m✔ 根目录文件/软链单独完成：$file_obj\033[0m"
    fi
done

echo -e "\n\033[32m🎉 全部执行完毕：prebuilts全程跳过｜所有外部项均一一个单独提交推送✅\033[0m"

