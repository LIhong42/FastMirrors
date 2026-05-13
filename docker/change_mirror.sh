#!/bin/bash
## Docker 镜像源自动换源脚本
## Author: FastMirrors Project
## License: MIT
## 参考: https://github.com/SuperManito/LinuxMirrors

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

# Docker 配置文件路径
DOCKER_DIR="/etc/docker"
DOCKER_CONFIG="${DOCKER_DIR}/daemon.json"
DOCKER_CONFIG_BACKUP="${DOCKER_DIR}/daemon.json.bak"

# 显示帮助信息
show_help() {
    echo -e "${BOLD}Docker 镜像源自动换源脚本${PLAIN}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -l, --list              列出所有可用的镜像源"
    echo "  -s, --set <地址>        设置指定的镜像源地址"
    echo "  -i, --interactive       交互式选择镜像源"
    echo "  -r, --restore           恢复备份的配置"
    echo "  -c, --current           显示当前配置的镜像源"
    echo "  -t, --test              测试镜像源连接速度"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -i                   交互式选择镜像源"
    echo "  $0 -s docker.1ms.run    设置指定镜像源"
    echo "  $0 -t                   测试所有镜像源速度"
    echo ""
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${ERROR} 权限不足，请使用 root 权限运行此脚本"
        echo "提示: sudo $0 $@"
        exit 1
    fi
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${ERROR} Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

# 创建 Docker 配置目录
ensure_docker_dir() {
    if [[ ! -d "${DOCKER_DIR}" ]]; then
        mkdir -p "${DOCKER_DIR}"
        echo -e "${SUCCESS} 已创建 Docker 配置目录: ${DOCKER_DIR}"
    fi
}

# 备份现有配置
backup_config() {
    if [[ -f "${DOCKER_CONFIG}" ]]; then
        cp "${DOCKER_CONFIG}" "${DOCKER_CONFIG_BACKUP}"
        echo -e "${SUCCESS} 已备份现有配置到: ${DOCKER_CONFIG_BACKUP}"
    fi
}

# 列出所有镜像源
list_mirrors() {
    echo -e "${BOLD}可用的 Docker 镜像源列表:${PLAIN}"
    echo ""
    local index=1
    while IFS='|' read -r url desc || [[ -n "$url" ]]; do
        # 跳过注释行和空行
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        printf "  ${GREEN}%2d${PLAIN}. %-45s %s\n" "$index" "$url" "$desc"
        ((index++))
    done < "${MIRRORS_FILE}"
    echo ""
}

# 获取镜像源列表数组
get_mirrors_array() {
    local mirrors=()
    while IFS='|' read -r url desc || [[ -n "$url" ]]; do
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        mirrors+=("$url")
    done < "${MIRRORS_FILE}"
    echo "${mirrors[@]}"
}

# 设置镜像源
set_mirror() {
    local mirror_url="$1"

    if [[ -z "$mirror_url" ]]; then
        echo -e "${ERROR} 请指定镜像源地址"
        exit 1
    fi

    ensure_docker_dir
    backup_config

    # 创建或更新 daemon.json
    if [[ -f "${DOCKER_CONFIG}" ]]; then
        # 使用临时文件处理 JSON
        local temp_file=$(mktemp)
        if python3 -c "import json" 2>/dev/null; then
            # 使用 Python 处理 JSON
            python3 -c "
import json
import sys

config = {}
try:
    with open('${DOCKER_CONFIG}', 'r') as f:
        config = json.load(f)
except:
    pass

config['registry-mirrors'] = ['https://${mirror_url}']

with open('${DOCKER_CONFIG}', 'w') as f:
    json.dump(config, f, indent=2)
"
        else
            # 简单处理：直接覆盖
            echo "{\"registry-mirrors\": [\"https://${mirror_url}\"]}" > "${DOCKER_CONFIG}"
        fi
    else
        echo "{\"registry-mirrors\": [\"https://${mirror_url}\"]}" > "${DOCKER_CONFIG}"
    fi

    echo -e "${SUCCESS} 已设置镜像源: ${mirror_url}"

    # 重启 Docker 服务
    echo -e "${BLUE}正在重启 Docker 服务...${PLAIN}"
    if systemctl restart docker; then
        echo -e "${SUCCESS} Docker 服务重启成功"
    else
        echo -e "${WARN} Docker 服务重启失败，请手动重启"
    fi

    # 验证配置
    echo ""
    echo -e "${BOLD}当前 Docker 镜像源配置:${PLAIN}"
    docker info 2>/dev/null | grep -A 5 "Registry Mirrors:" || echo "无法获取镜像源信息"
}

# 交互式选择镜像源
interactive_select() {
    list_mirrors

    local mirrors=($(get_mirrors_array))
    local count=${#mirrors[@]}

    echo -e "请输入镜像源序号 [1-${count}]，或输入 0 退出:"
    read -r choice

    if [[ "$choice" == "0" ]]; then
        echo "已取消操作"
        exit 0
    fi

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$count" ]]; then
        echo -e "${ERROR} 无效的选择"
        exit 1
    fi

    local selected_mirror="${mirrors[$((choice-1))]}"
    echo -e "${BLUE}您选择了: ${selected_mirror}${PLAIN}"

    set_mirror "$selected_mirror"
}

# 恢复备份配置
restore_config() {
    if [[ -f "${DOCKER_CONFIG_BACKUP}" ]]; then
        cp "${DOCKER_CONFIG_BACKUP}" "${DOCKER_CONFIG}"
        echo -e "${SUCCESS} 已恢复备份配置"

        systemctl restart docker
        echo -e "${SUCCESS} Docker 服务已重启"
    else
        echo -e "${ERROR} 未找到备份文件: ${DOCKER_CONFIG_BACKUP}"
        exit 1
    fi
}

# 显示当前配置
show_current() {
    echo -e "${BOLD}当前 Docker 配置:${PLAIN}"
    if [[ -f "${DOCKER_CONFIG}" ]]; then
        cat "${DOCKER_CONFIG}"
    else
        echo "配置文件不存在: ${DOCKER_CONFIG}"
    fi

    echo ""
    echo -e "${BOLD}Docker 信息中的镜像源:${PLAIN}"
    docker info 2>/dev/null | grep -A 5 "Registry Mirrors:" || echo "未配置镜像源"
}

# 测试镜像源速度
test_mirrors() {
    echo -e "${BOLD}测试镜像源连接速度...${PLAIN}"
    echo ""

    local mirrors=($(get_mirrors_array))
    local results=()

    for mirror in "${mirrors[@]}"; do
        echo -n "测试 ${mirror}... "
        local start_time=$(date +%s%N)
        if curl -s --connect-timeout 3 "https://${mirror}/v2/" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local duration=$(( (end_time - start_time) / 1000000 ))
            echo -e "${GREEN}${duration}ms${PLAIN}"
            results+=("${duration}|${mirror}")
        else
            echo -e "${RED}超时${PLAIN}"
            results+=("999999|${mirror}")
        fi
    done

    # 排序并显示结果
    echo ""
    echo -e "${BOLD}镜像源速度排名 (从快到慢):${PLAIN}"
    IFS=$'\n' sorted=($(sort -t'|' -k1 -n <<<"${results[*]}"))
    unset IFS

    local rank=1
    for result in "${sorted[@]}"; do
        local time=$(echo "$result" | cut -d'|' -f1)
        local mirror=$(echo "$result" | cut -d'|' -f2)
        if [[ "$time" == "999999" ]]; then
            printf "  %2d. %-45s ${RED}不可用${PLAIN}\n" "$rank" "$mirror"
        else
            printf "  %2d. %-45s ${GREEN}%sms${PLAIN}\n" "$rank" "$mirror" "$time"
        fi
        ((rank++))
    done
}

# 主函数
main() {
    local action=""
    local mirror_url=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list)
                action="list"
                shift
                ;;
            -s|--set)
                action="set"
                mirror_url="$2"
                shift 2
                ;;
            -i|--interactive)
                action="interactive"
                shift
                ;;
            -r|--restore)
                action="restore"
                shift
                ;;
            -c|--current)
                action="current"
                shift
                ;;
            -t|--test)
                action="test"
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

    # 默认显示帮助
    if [[ -z "$action" ]]; then
        show_help
        exit 0
    fi

    # 执行操作
    case "$action" in
        list)
            list_mirrors
            ;;
        set)
            check_root
            check_docker
            set_mirror "$mirror_url"
            ;;
        interactive)
            check_root
            check_docker
            interactive_select
            ;;
        restore)
            check_root
            restore_config
            ;;
        current)
            show_current
            ;;
        test)
            test_mirrors
            ;;
    esac
}

main "$@"
