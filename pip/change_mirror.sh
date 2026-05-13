#!/bin/bash
## pip 镜像源自动换源脚本
## Author: FastMirrors Project
## License: MIT

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

# pip 配置文件路径
PIP_CONFIG_DIR="${HOME}/.pip"
PIP_CONFIG_FILE="${PIP_CONFIG_DIR}/pip.conf"

# 显示帮助信息
show_help() {
    echo -e "${BOLD}pip 镜像源自动换源脚本${PLAIN}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -l, --list              列出所有可用的镜像源"
    echo "  -s, --set <地址>        设置指定的镜像源地址"
    echo "  -i, --interactive       交互式选择镜像源"
    echo "  -a, --auto              自动换源(测速后选择最快的源)"
    echo "  -r, --restore           恢复默认配置"
    echo "  -c, --current           显示当前配置的镜像源"
    echo "  -g, --global            设置全局配置(需要root权限)"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -i                   交互式选择镜像源"
    echo "  $0 -s pypi.tuna.tsinghua.edu.cn/simple  设置清华镜像源"
    echo "  $0 -a                   自动换源(测速后选择最快的源)"
    echo "  $0 -g -i                全局设置镜像源"
    echo ""
}

# 创建 pip 配置目录
ensure_pip_dir() {
    if [[ ! -d "${PIP_CONFIG_DIR}" ]]; then
        mkdir -p "${PIP_CONFIG_DIR}"
        echo -e "${SUCCESS} 已创建 pip 配置目录: ${PIP_CONFIG_DIR}"
    fi
}

# 列出所有镜像源
list_mirrors() {
    echo -e "${BOLD}可用的 pip 镜像源列表:${PLAIN}"
    echo ""
    local index=1
    while IFS='|' read -r url desc trusted_host || [[ -n "$url" ]]; do
        # 跳过注释行和空行
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        printf "  ${GREEN}%2d${PLAIN}. %-50s %s\n" "$index" "$url" "$desc"
        ((index++))
    done < "${MIRRORS_FILE}"
    echo ""
}

# 获取镜像源列表数组
get_mirrors_array() {
    local mirrors=()
    while IFS='|' read -r url desc trusted_host || [[ -n "$url" ]]; do
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        mirrors+=("$url|$trusted_host")
    done < "${MIRRORS_FILE}"
    echo "${mirrors[@]}"
}

# 设置镜像源
set_mirror() {
    local mirror_url="$1"
    local trusted_host="$2"
    local is_global="$3"

    if [[ -z "$mirror_url" ]]; then
        echo -e "${ERROR} 请指定镜像源地址"
        exit 1
    fi

    # 全局配置需要 root 权限
    if [[ "$is_global" == "true" ]]; then
        if [[ $EUID -ne 0 ]]; then
            echo -e "${ERROR} 全局配置需要 root 权限"
            echo "提示: sudo $0 -g -s $mirror_url"
            exit 1
        fi
        PIP_CONFIG_DIR="/etc"
        PIP_CONFIG_FILE="${PIP_CONFIG_DIR}/pip.conf"
    fi

    ensure_pip_dir

    # 备份现有配置
    if [[ -f "${PIP_CONFIG_FILE}" ]]; then
        cp "${PIP_CONFIG_FILE}" "${PIP_CONFIG_FILE}.bak"
        echo -e "${SUCCESS} 已备份现有配置"
    fi

    # 生成配置文件
    cat > "${PIP_CONFIG_FILE}" << EOF
[global]
index-url = https://${mirror_url}
trusted-host = ${trusted_host}
timeout = 120

[install]
trusted-host = ${trusted_host}
EOF

    if [[ "$is_global" == "true" ]]; then
        echo -e "${SUCCESS} 已设置全局 pip 镜像源: ${mirror_url}"
    else
        echo -e "${SUCCESS} 已设置用户 pip 镜像源: ${mirror_url}"
    fi

    # 验证配置
    echo ""
    echo -e "${BOLD}当前 pip 配置:${PLAIN}"
    pip config list 2>/dev/null || pip3 config list 2>/dev/null || cat "${PIP_CONFIG_FILE}"
}

# 交互式选择镜像源
interactive_select() {
    local is_global="$1"

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

    local selected="${mirrors[$((choice-1))]}"
    local mirror_url=$(echo "$selected" | cut -d'|' -f1)
    local trusted_host=$(echo "$selected" | cut -d'|' -f2)

    echo -e "${BLUE}您选择了: ${mirror_url}${PLAIN}"

    set_mirror "$mirror_url" "$trusted_host" "$is_global"
}

# 自动换源 (测速后选择最快的源)
auto_change_mirror() {
    local is_global="$1"

    echo -e "${BOLD}========================================${PLAIN}"
    echo -e "${BOLD}    pip 镜像源自动换源${PLAIN}"
    echo -e "${BOLD}========================================${PLAIN}"
    echo ""

    # 全局配置需要 root 权限
    if [[ "$is_global" == "true" ]]; then
        if [[ $EUID -ne 0 ]]; then
            echo -e "${ERROR} 全局配置需要 root 权限"
            echo "提示: sudo $0 -g -a"
            exit 1
        fi
        PIP_CONFIG_DIR="/etc"
        PIP_CONFIG_FILE="${PIP_CONFIG_DIR}/pip.conf"
        echo -e "${BLUE}配置模式: 全局配置${PLAIN}"
    else
        echo -e "${BLUE}配置模式: 用户配置${PLAIN}"
    fi
    echo ""

    # Step 1: 备份原始源
    echo -e "${BLUE}[Step 1] 备份原始 pip 配置...${PLAIN}"
    if [[ -f "${PIP_CONFIG_FILE}" ]]; then
        local backup_file="${PIP_CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${PIP_CONFIG_FILE}" "$backup_file"
        echo -e "${SUCCESS} 已备份到: ${backup_file}"
    else
        echo -e "${WARN} 未找到 pip 配置文件，跳过备份"
    fi
    echo ""

    # Step 2: 运行测速脚本
    echo -e "${BLUE}[Step 2] 运行测速脚本...${PLAIN}"
    local speed_test_script="${SCRIPT_DIR}/speed_test.sh"
    if [[ ! -f "$speed_test_script" ]]; then
        echo -e "${ERROR} 未找到测速脚本: ${speed_test_script}"
        exit 1
    fi

    # 运行测速并更新 mirrors.txt
    bash "$speed_test_script"
    echo ""

    # Step 3: 选择最快的源
    echo -e "${BLUE}[Step 3] 选择最快的镜像源...${PLAIN}"

    local fastest_mirror=""
    local fastest_host=""
    while IFS='|' read -r url desc host || [[ -n "$url" ]]; do
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        fastest_mirror="$url"
        fastest_host="$host"
        break
    done < "${MIRRORS_FILE}"

    if [[ -z "$fastest_mirror" ]]; then
        echo -e "${ERROR} 未找到可用的镜像源"
        exit 1
    fi

    echo -e "${SUCCESS} 最快的镜像源: ${fastest_mirror}"
    echo ""

    # Step 4: 设置镜像源
    echo -e "${BLUE}[Step 4] 设置镜像源...${PLAIN}"
    set_mirror "$fastest_mirror" "$fastest_host" "$is_global"

    echo ""
    echo -e "${GREEN}${BOLD}自动换源完成!${PLAIN}"
    echo -e "${BOLD}已更换为最快的镜像源: ${fastest_mirror}${PLAIN}"
}

# 恢复默认配置
restore_config() {
    if [[ -f "${PIP_CONFIG_FILE}.bak" ]]; then
        mv "${PIP_CONFIG_FILE}.bak" "${PIP_CONFIG_FILE}"
        echo -e "${SUCCESS} 已恢复备份配置"
    elif [[ -f "${PIP_CONFIG_FILE}" ]]; then
        rm "${PIP_CONFIG_FILE}"
        echo -e "${SUCCESS} 已删除自定义配置，恢复默认"
    else
        echo -e "${WARN} 未找到备份文件"
    fi
}

# 显示当前配置
show_current() {
    echo -e "${BOLD}当前 pip 配置:${PLAIN}"
    echo ""

    if [[ -f "${PIP_CONFIG_FILE}" ]]; then
        echo "配置文件: ${PIP_CONFIG_FILE}"
        echo ""
        cat "${PIP_CONFIG_FILE}"
    else
        echo "未找到配置文件，使用默认配置"
    fi

    echo ""
    echo -e "${BOLD}pip config list 输出:${PLAIN}"
    pip config list 2>/dev/null || pip3 config list 2>/dev/null || echo "无法获取配置"
}


# 主函数
main() {
    local action=""
    local mirror_url=""
    local trusted_host=""
    local is_global="false"

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
            -a|--auto)
                action="auto"
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
            -g|--global)
                is_global="true"
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
            # 从镜像列表获取 trusted-host
            while IFS='|' read -r url desc host || [[ -n "$url" ]]; do
                [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
                if [[ "$url" == "$mirror_url" ]]; then
                    trusted_host="$host"
                    break
                fi
            done < "${MIRRORS_FILE}"

            if [[ -z "$trusted_host" ]]; then
                trusted_host=$(echo "$mirror_url" | cut -d'/' -f1)
            fi

            set_mirror "$mirror_url" "$trusted_host" "$is_global"
            ;;
        interactive)
            interactive_select "$is_global"
            ;;
        auto)
            auto_change_mirror "$is_global"
            ;;
        restore)
            restore_config
            ;;
        current)
            show_current
            ;;
    esac
}

main "$@"
