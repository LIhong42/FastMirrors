#!/bin/bash
## FastMirrors - 快速换源工具集
## Author: FastMirrors Project
## License: MIT

set -e

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
CYAN='\033[36m'
PLAIN='\033[0m'
BOLD='\033[1m'

# 显示 Logo
show_logo() {
    echo -e "${CYAN}"
    echo "  ███████╗ █████╗ ███████╗███████╗██╗███╗   ██╗███████╗"
    echo "  ██╔════╝██╔══██╗██╔════╝██╔════╝██║████╗  ██║██╔════╝"
    echo "  █████╗  ███████║███████╗███████╗██║██╔██╗ ██║█████╗  "
    echo "  ██╔══╝  ██╔══██║╚════██║╚════██║██║██║╚██╗██║██╔══╝  "
    echo "  ██║     ██║  ██║███████║███████║██║██║ ╚████║███████╗"
    echo "  ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝"
    echo -e "${PLAIN}"
    echo -e "  ${BOLD}快速换源工具集 - 让换源更简单${PLAIN}"
    echo ""
}

# 显示帮助信息
show_help() {
    show_logo
    echo -e "${BOLD}用法:${PLAIN}"
    echo "  $0 <命令> [选项]"
    echo ""
    echo -e "${BOLD}命令:${PLAIN}"
    echo -e "  ${GREEN}docker${PLAIN}     Docker 镜像源管理"
    echo -e "  ${GREEN}linux${PLAIN}      Linux 软件源管理"
    echo -e "  ${GREEN}pip${PLAIN}        pip 镜像源管理"
    echo -e "  ${GREEN}all${PLAIN}        一键更换所有源(交互式)"
    echo ""
    echo -e "${BOLD}示例:${PLAIN}"
    echo "  $0 docker -i        # 交互式选择 Docker 镜像源"
    echo "  $0 linux -i         # 交互式选择 Linux 软件源"
    echo "  $0 pip -i           # 交互式选择 pip 镜像源"
    echo "  $0 all              # 一键更换所有源"
    echo ""
    echo -e "${BOLD}获取更多帮助:${PLAIN}"
    echo "  $0 docker --help    # 查看 Docker 换源帮助"
    echo "  $0 linux --help     # 查看 Linux 换源帮助"
    echo "  $0 pip --help       # 查看 pip 换源帮助"
    echo ""
}

# Docker 换源
run_docker() {
    local script="${SCRIPT_DIR}/docker/change_mirror.sh"
    if [[ -f "$script" ]]; then
        bash "$script" "$@"
    else
        echo -e "${RED}错误: 找不到 Docker 换源脚本${PLAIN}"
        exit 1
    fi
}

# Linux 换源
run_linux() {
    local script="${SCRIPT_DIR}/linux/change_mirror.sh"
    if [[ -f "$script" ]]; then
        bash "$script" "$@"
    else
        echo -e "${RED}错误: 找不到 Linux 换源脚本${PLAIN}"
        exit 1
    fi
}

# pip 换源
run_pip() {
    local script="${SCRIPT_DIR}/pip/change_mirror.sh"
    if [[ -f "$script" ]]; then
        bash "$script" "$@"
    else
        echo -e "${RED}错误: 找不到 pip 换源脚本${PLAIN}"
        exit 1
    fi
}

# 一键换源
run_all() {
    show_logo

    echo -e "${BOLD}${BLUE}=== Docker 镜像源 ===${PLAIN}"
    run_docker -i
    echo ""

    echo -e "${BOLD}${BLUE}=== Linux 软件源 ===${PLAIN}"
    echo -e "${YELLOW}注意: Linux 换源需要 root 权限${PLAIN}"
    read -p "是否继续更换 Linux 软件源? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        run_linux -i
    fi
    echo ""

    echo -e "${BOLD}${BLUE}=== pip 镜像源 ===${PLAIN}"
    run_pip -i
    echo ""

    echo -e "${GREEN}${BOLD}全部换源完成!${PLAIN}"
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        docker)
            run_docker "$@"
            ;;
        linux)
            run_linux "$@"
            ;;
        pip)
            run_pip "$@"
            ;;
        all)
            run_all
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            echo -e "${RED}错误: 未知命令 '${command}'${PLAIN}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
