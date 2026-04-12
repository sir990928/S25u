#!/bin/bash
# 修复容量爆炸：仅实体文件算大小｜软链不计容量｜prebuilts专属800M进度分片
BRANCH="main"
SELF_SCRIPT="1.sh"
PREBUILTS_DIR="kernel_platform/prebuilts"
SIZE_LIMIT=$((800 * 1024 * 1024))
MAX_SINGLE=$((95 * 1024 * 1024))

cd "/workspaces/S25ultra" || exit 1
git config core.symlinks true
git config http.postBuffer 2147483648

##########################################################################
# 第一部分：prebuilts 专属 800M分片 + 正确容量统计 + 进度条
##########################################################################
echo -e "\033[35m========== [1] 800M分片处理：${PREBUILTS_DIR}（仅此处显示进度） ==========\033[0m"
counter=0
batch_size=0
clean_arr=()

# 列出所有 文件/软链
find "${PREBUILTS_DIR}" \( -type f -o -type l \) ! -path "*/.git/*" ! -name "${SELF_SCRIPT}" -print > pre_list.tmp
total_pre=$(wc -l < pre_list.tmp)
echo -e "\033[36mprebuilts 总待处理：${total_pre} 个\033[0m"

shopt -s dotglob nullglob
IFS=$'\n'
for item in $(cat pre_list.tmp); do
    fsz=0
    skip=0
    # ========== 关键修复：仅普通文件取大小，软链接不统计容量 ==========
    if [[ -f "$item" && ! -L "$item" ]]; then
        fsz=$(stat -c%s "$item" 2>/dev/null || 0)
        if (( fsz > MAX_SINGLE )); then
            echo -e "\n\033[33m⚠️ 跳过超大文件 >95MB：$item\033[0m"
            skip=1
        fi
    fi
    ((skip)) && continue

    git add -- "$item" 2>/dev/null
    clean_arr+=("$item")
    ((counter++))
    ((batch_size += fsz))

    # 进度显示 MB 格式化
    show_mb=$(( batch_size / 1024 / 1024 ))
    per=$(( counter * 100 / total_pre ))
    [[ -L "$item" ]] && tag="L" || tag="F"
    echo -ne "\r\033[34m[${per}%] ${counter}/${total_pre} [${tag}] ${item: -30} | 累计${show_mb}M/800M\033[0m"

    # 满800M提交推送+批量清理防卡顿
    if (( batch_size >= SIZE_LIMIT )); then
        echo -e "\n\033[32m✅ 达800M阈值，批次提交推送\033[0m"
        git commit -m "prebuilts_800_batch_${counter}" --quiet
        until git push -f origin "$BRANCH"; do echo "推送重试5s"; sleep 5;done

        printf "%s\n" "${clean_arr[@]}" | git update-index --assume-unchanged --stdin 2>/dev/null
        printf "%s\n" "${clean_arr[@]}" | xargs -r rm -f -- 2>/dev/null

        clean_arr=()
        counter=0
        batch_size=0
        echo -e "\033[32m🧹 本轮清理完毕，继续累积\n\033[0m"
    fi
done
unset IFS; shopt -u dotglob

# 尾部余量提交
if (( ${#clean_arr[@]} > 0 )); then
    echo -e "\n\033[32m📦 prebuilts 收尾余量上传\033[0m"
    git commit -m "prebuilts_800_tail_final" --quiet
    until git push -f origin "$BRANCH"; do sleep 5;done
    printf "%s\n" "${clean_arr[@]}" | git update-index --assume-unchanged --stdin 2>/dev/null
    printf "%s\n" "${clean_arr[@]}" | xargs -r rm -f -- 2>/dev/null
fi
rm -f pre_list.tmp

##########################################################################
# 第二部分：根目录同级文件夹 单独add外层（不进内部）
##########################################################################
echo -e "\n\033[35m========== [2] 根目录外层文件夹逐个提交（不深入内部） ==========\033[0m"
for dir_obj in ./*; do
    [[ "$dir_obj" == "./.git" || "$dir_obj" == "./kernel_platform" ]] && continue
    [[ -d "$dir_obj" ]] && {
        git add -- "$dir_obj" 2>/dev/null
        echo -e "\033[32m📁 提交外层目录：$dir_obj\033[0m"
    }
done

##########################################################################
# 第三部分：根目录独立文件/软链逐个add（含其他脚本）
##########################################################################
echo -e "\n\033[35m========== [3] 根目录独立文件/软链逐个提交 ==========\033[0m"
for file_obj in ./*; do
    [[ "$file_obj" == "./.git" || "$file_obj" == "./kernel_platform" ]] && continue
    [[ -f "$file_obj" || -L "$file_obj" ]] && {
        git add -- "$file_obj" 2>/dev/null
        echo -e "\033[32m📄 提交独立文件/软链：$file_obj\033[0m"
    }
done

##########################################################################
# 全局收尾
##########################################################################
echo -e "\n\033[35m========== [4] 全局最终汇总推送 ==========\033[0m"
if ! git diff --cached --quiet; then
    git commit -m "root_all_other_complete_final" --quiet
    until git push -f origin "$BRANCH"; do sleep 5;done
fi

echo -e "\n\033[32m🎉 修复完成：容量正常统计｜仅prebuilts 800M进度分片｜外层单独提交✅\033[0m"

