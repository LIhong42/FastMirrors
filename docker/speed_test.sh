#!/bin/bash
## Docker 镜像源测速脚本
## Author: FastMirrors Project
## License: MIT
## 功能: 测试镜像源速度并按速度排序更新 mirrors.txt

set -e

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRRORS_FILE="${SCRIPT_DIR}/mirrors.txt"

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'
BOLD='\033[1m'

SUCCESS="${GREEN}✔${PLAIN}"
ERROR="${RED}✘${PLAIN}"
WARN="${YELLOW}!${PLAIN}"

# 测试超时时间(秒)
TEST_TIMEOUT=5

# 测试次数
TEST_COUNT=3

# 显示帮助信息
show_help() {
    echo -e "${BOLD}Docker 镜像源测速脚本${PLAIN}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -t, --timeout <秒>     设置超时时间 (默认: 5秒)"
    echo "  -n, --count <次数>     每个镜像测试次数 (默认: 3次)"
    echo "  -o, --output           仅输出结果，不更新 mirrors.txt"
    echo "  -h, --help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                     测速并更新 mirrors.txt"
    echo "  $0 -t 10               使用10秒超时"
    echo "  $0 -o                  仅显示测速结果"
    echo ""
}

# 解析参数
OUTPUT_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        -n|--count)
            TEST_COUNT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${ERROR} 未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 测试单个镜像源速度
test_single_mirror() {
    local mirror_url="$1"
    local test_url="https://${mirror_url}/v2/"
    local total_time=0
    local success_count=0

    for ((i=1; i<=TEST_COUNT; i++)); do
        local start_time=$(date +%s%N)
        if curl -s --connect-timeout "${TEST_TIMEOUT}" --max-time "${TEST_TIMEOUT}" "${test_url}" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local duration=$(( (end_time - start_time) / 1000000 ))
            total_time=$((total_time + duration))
            ((success_count++))
        fi
    done

    if [[ $success_count -eq 0 ]]; then
        echo "999999"  # 超时/失败
    else
        echo $((total_time / success_count))
    fi
}

# 读取镜像源列表
read_mirrors() {
    local mirrors=()
    local descs=()

    while IFS='|' read -r url desc || [[ -n "$url" ]]; do
        # 跳过注释行和空行
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        mirrors+=("$url")
        descs+=("$desc")
    done < "${MIRRORS_FILE}"

    MIRRORS=("${mirrors[@]}")
    DESCRIPTONS=("${descs[@]}")
}

# 主测速函数
run_speed_test() {
    echo -e "${BOLD}========================================${PLAIN}"
    echo -e "${BOLD}    Docker 镜像源测速工具${PLAIN}"
    echo -e "${BOLD}========================================${PLAIN}"
    echo ""

    echo -e "${BLUE}测试参数: 超时=${TEST_TIMEOUT}秒, 每镜像测试${TEST_COUNT}次${PLAIN}"
    echo ""

    read_mirrors
    local count=${#MIRRORS[@]}

    if [[ $count -eq 0 ]]; then
        echo -e "${ERROR} 未找到镜像源配置"
        exit 1
    fi

    echo -e "${BOLD}开始测试 ${count} 个镜像源...${PLAIN}"
    echo ""

    # 存储结果: 时间|URL|描述
    local results=()

    for ((i=0; i<count; i++)); do
        local mirror="${MIRRORS[$i]}"
        local desc="${DESCRIPTONS[$i]}"

        printf "  [%2d/%d] 测试 %-45s " "$((i+1))" "$count" "$mirror"

        local avg_time=$(test_single_mirror "$mirror")

        if [[ "$avg_time" == "999999" ]]; then
            echo -e "${RED}超时/失败${PLAIN}"
            results+=("${avg_time}|${mirror}|${desc}")
        else
            echo -e "${GREEN}${avg_time}ms${PLAIN}"
            results+=("${avg_time}|${mirror}|${desc}")
        fi
    done

    echo ""
    echo -e "${BOLD}========================================${PLAIN}"
    echo -e "${BOLD}    测速结果 (按速度排序)${PLAIN}"
    echo -e "${BOLD}========================================${PLAIN}"
    echo ""

    # 按时间排序
    IFS=$'\n' sorted=($(echo "${results[*]}" | tr ' ' '\n' | sort -t'|' -k1 -n))
    unset IFS

    # 显示排序结果
    printf "${BOLD}%-6s %-45s %12s %s${PLAIN}\n" "排名" "镜像地址" "延迟" "描述"
    echo "----------------------------------------------------------------------"

    local rank=1
    local valid_count=0
    local new_content="# Docker 镜像仓库列表\n# 格式: 镜像地址|描述\n# 使用时请根据网络环境选择合适的镜像源\n# 最后更新: $(date '+%Y-%m-%d %H:%M:%S')\n\n"

    for result in "${sorted[@]}"; do
        local time=$(echo "$result" | cut -d'|' -f1)
        local mirror=$(echo "$result" | cut -d'|' -f2)
        local desc=$(echo "$result" | cut -d'|' -f3)

        if [[ "$time" == "999999" ]]; then
            printf "${RED}%-6s %-45s %12s %s${PLAIN}\n" "$rank" "$mirror" "不可用" "$desc"
            # 不可用的放到最后
            new_content+="${mirror}|${desc}\n"
        else
            printf "${GREEN}%-6s %-45s %12s %s${PLAIN}\n" "$rank" "$mirror" "${time}ms" "$desc"
            new_content+="${mirror}|${desc}\n"
            ((valid_count++))
        fi
        ((rank++))
    done

    echo ""
    echo -e "${BOLD}统计: 可用 ${GREEN}${valid_count}${PLAIN} / 总计 ${count}${PLAIN}"

    # 更新 mirrors.txt
    if [[ "$OUTPUT_ONLY" == "false" ]]; then
        echo ""
        echo -e "${BLUE}正在更新 mirrors.txt...${PLAIN}"

        # 备份原文件
        cp "${MIRRORS_FILE}" "${MIRRORS_FILE}.bak"

        # 写入新内容
        echo -e "$new_content" > "${MIRRORS_FILE}"

        echo -e "${SUCCESS} 已更新 mirrors.txt (备份: mirrors.txt.bak)"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}测速完成!${PLAIN}"
}

# 运行测速
run_speed_test
