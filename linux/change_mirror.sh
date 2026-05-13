#!/bin/bash
## Linux 软件源自动换源脚本
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

# 显示帮助信息
show_help() {
    echo -e "${BOLD}Linux 软件源自动换源脚本${PLAIN}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -l, --list              列出所有可用的镜像源"
    echo "  -s, --set <地址>        设置指定的镜像源地址"
    echo "  -i, --interactive       交互式选择镜像源"
    echo "  -a, --auto              自动换源(测速后选择最快的源)"
    echo "  -r, --restore           恢复备份的源配置"
    echo "  -c, --current           显示当前软件源配置"
    echo "  -u, --update            换源后更新软件包"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo -e "${BOLD}支持的系统:${PLAIN}"
    echo ""
    echo -e "  ${GREEN}Debian 系:${PLAIN}"
    echo "    - Debian 9-13 (stretch, buster, bullseye, bookworm, trixie)"
    echo "    - Ubuntu 14-26 (trusty, xenial, bionic, focal, jammy, noble)"
    echo "    - Kali Linux (kali-rolling)"
    echo "    - Deepin 20/23 (apricot, beige)"
    echo "    - Linux Mint 19-22"
    echo ""
    echo -e "  ${GREEN}RHEL 系:${PLAIN}"
    echo "    - CentOS 7"
    echo "    - CentOS Stream 8-10"
    echo "    - Rocky Linux 8-10"
    echo "    - AlmaLinux 8-10"
    echo "    - Fedora 30-43"
    echo ""
    echo -e "  ${GREEN}其他:${PLAIN}"
    echo "    - Arch Linux / Manjaro"
    echo "    - Alpine Linux v3 / edge"
    echo ""
    echo -e "${BOLD}示例:${PLAIN}"
    echo "  $0 -i                   交互式选择镜像源"
    echo "  $0 -s mirrors.aliyun.com 设置阿里云镜像源"
    echo "  $0 -u                   换源并更新软件包"
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

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        SYSTEM_ID="${ID}"
        SYSTEM_VERSION_ID="${VERSION_ID}"
        SYSTEM_PRETTY_NAME="${PRETTY_NAME}"
    elif [[ -f /etc/redhat-release ]]; then
        SYSTEM_ID="centos"
        SYSTEM_PRETTY_NAME=$(cat /etc/redhat-release)
    elif [[ -f /etc/arch-release ]]; then
        SYSTEM_ID="arch"
        SYSTEM_PRETTY_NAME="Arch Linux"
    elif [[ -f /etc/alpine-release ]]; then
        SYSTEM_ID="alpine"
        SYSTEM_PRETTY_NAME="Alpine Linux"
    else
        echo -e "${ERROR} 无法检测系统类型"
        exit 1
    fi

    echo -e "${SUCCESS} 检测到系统: ${SYSTEM_PRETTY_NAME}"
}

# 获取系统源文件路径
get_source_file() {
    case "${SYSTEM_ID}" in
        debian|ubuntu|kali|deepin|linuxmint)
            echo "/etc/apt/sources.list"
            ;;
        centos|rhel|rocky|almalinux|fedora)
            echo "/etc/yum.repos.d"
            ;;
        arch|manjaro)
            echo "/etc/pacman.d/mirrorlist"
            ;;
        alpine)
            echo "/etc/apk/repositories"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 备份源配置
backup_source() {
    local source_file="$1"
    local backup_file="${source_file}.bak.$(date +%Y%m%d%H%M%S)"

    if [[ -f "$source_file" ]]; then
        cp "$source_file" "$backup_file"
        echo -e "${SUCCESS} 已备份源配置到: ${backup_file}"
    fi
}

# 列出所有镜像源
list_mirrors() {
    echo -e "${BOLD}可用的 Linux 软件源列表:${PLAIN}"
    echo ""
    local index=1
    while IFS='|' read -r url desc systems || [[ -n "$url" ]]; do
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
    while IFS='|' read -r url desc systems || [[ -n "$url" ]]; do
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        mirrors+=("$url")
    done < "${MIRRORS_FILE}"
    echo "${mirrors[@]}"
}

# Debian 换源
change_debian_source() {
    local mirror_url="$1"
    local source_file="/etc/apt/sources.list"

    backup_source "$source_file"

    # 获取系统代号 (bookworm, bullseye, buster 等)
    local codename=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2)
    # 如果没有获取到，尝试从 VERSION_ID 解析
    if [[ -z "$codename" ]]; then
        case "${SYSTEM_VERSION_ID}" in
            13|13.*) codename="bookworm" ;;
            12|12.*) codename="bullseye" ;;
            11|11.*) codename="buster" ;;
            10|10.*) codename="stretch" ;;
            9|9.*)   codename="jessie" ;;
            *)       codename="bookworm" ;;  # 默认使用最新
        esac
    fi

    echo -e "${BLUE}正在生成 Debian 软件源配置...${PLAIN}"
    echo -e "${SUCCESS} 系统代号: ${codename}"

    # Debian 12 (bookworm) 及以上新增 non-free-firmware
    local non_free_section=""
    if [[ "$codename" == "bookworm" || "$codename" == "trixie" || "$codename" == "sid" ]]; then
        non_free_section="non-free non-free-firmware"
    else
        non_free_section="non-free"
    fi

    # 生成 sources.list
    cat > "$source_file" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: Debian ${codename}

deb https://${mirror_url}/debian/ ${codename} main contrib ${non_free_section}
deb https://${mirror_url}/debian/ ${codename}-updates main contrib ${non_free_section}
deb https://${mirror_url}/debian-security/ ${codename}-security main contrib ${non_free_section}
deb https://${mirror_url}/debian/ ${codename}-backports main contrib ${non_free_section}

# 源码包 (可选)
# deb-src https://${mirror_url}/debian/ ${codename} main contrib ${non_free_section}
# deb-src https://${mirror_url}/debian/ ${codename}-updates main contrib ${non_free_section}
# deb-src https://${mirror_url}/debian-security/ ${codename}-security main contrib ${non_free_section}
# deb-src https://${mirror_url}/debian/ ${codename}-backports main contrib ${non_free_section}
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 更新软件源缓存
    echo -e "${BLUE}正在更新软件源缓存...${PLAIN}"
    apt-get update
    echo -e "${SUCCESS} 软件源缓存更新完成"
}

# Ubuntu 换源
change_ubuntu_source() {
    local mirror_url="$1"
    local source_file="/etc/apt/sources.list"

    backup_source "$source_file"

    # 获取系统代号 (focal, jammy, noble 等)
    local codename=$(lsb_release -cs 2>/dev/null)
    # 如果没有获取到，尝试从 VERSION_ID 解析
    if [[ -z "$codename" ]]; then
        case "${SYSTEM_VERSION_ID}" in
            26|26.*) codename="noble" ;;      # Ubuntu 26.04
            24|24.*) codename="noble" ;;      # Ubuntu 24.04
            22|22.*) codename="jammy" ;;      # Ubuntu 22.04
            20|20.*) codename="focal" ;;      # Ubuntu 20.04
            18|18.*) codename="bionic" ;;     # Ubuntu 18.04
            16|16.*) codename="xenial" ;;     # Ubuntu 16.04
            14|14.*) codename="trusty" ;;     # Ubuntu 14.04
            *)       codename="noble" ;;      # 默认使用最新 LTS
        esac
    fi

    echo -e "${BLUE}正在生成 Ubuntu 软件源配置...${PLAIN}"
    echo -e "${SUCCESS} 系统代号: ${codename}"

    # 生成 sources.list
    cat > "$source_file" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: Ubuntu ${codename}

deb https://${mirror_url}/ubuntu/ ${codename} main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ ${codename}-updates main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ ${codename}-backports main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ ${codename}-security main restricted universe multiverse

# 源码包 (可选)
# deb-src https://${mirror_url}/ubuntu/ ${codename} main restricted universe multiverse
# deb-src https://${mirror_url}/ubuntu/ ${codename}-updates main restricted universe multiverse
# deb-src https://${mirror_url}/ubuntu/ ${codename}-backports main restricted universe multiverse
# deb-src https://${mirror_url}/ubuntu/ ${codename}-security main restricted universe multiverse
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 更新软件源缓存
    echo -e "${BLUE}正在更新软件源缓存...${PLAIN}"
    apt-get update
    echo -e "${SUCCESS} 软件源缓存更新完成"
}

# Kali Linux 换源
change_kali_source() {
    local mirror_url="$1"
    local source_file="/etc/apt/sources.list"

    backup_source "$source_file"

    echo -e "${BLUE}正在生成 Kali Linux 软件源配置...${PLAIN}"

    # Kali Linux 使用 kali-rolling 作为默认分支
    cat > "$source_file" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: Kali Linux

deb https://${mirror_url}/kali/ kali-rolling main contrib non-free non-free-firmware

# 源码包 (可选)
# deb-src https://${mirror_url}/kali/ kali-rolling main contrib non-free non-free-firmware
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 更新软件源缓存
    echo -e "${BLUE}正在更新软件源缓存...${PLAIN}"
    apt-get update
    echo -e "${SUCCESS} 软件源缓存更新完成"
}

# Deepin 换源
change_deepin_source() {
    local mirror_url="$1"
    local source_file="/etc/apt/sources.list"

    backup_source "$source_file"

    # 获取 Deepin 版本代号
    local codename=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d= -f2)
    if [[ -z "$codename" ]]; then
        # Deepin 23 使用 "beige"，Deepin 20 使用 "apricot"
        codename="beige"
    fi

    echo -e "${BLUE}正在生成 Deepin 软件源配置...${PLAIN}"
    echo -e "${SUCCESS} 系统代号: ${codename}"

    # Deepin 有自己的仓库结构
    cat > "$source_file" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: Deepin ${codename}

deb https://${mirror_url}/deepin/ ${codename} main commercial community
deb https://${mirror_url}/deepin/ ${codename}-updates main commercial community

# 源码包 (可选)
# deb-src https://${mirror_url}/deepin/ ${codename} main commercial community
# deb-src https://${mirror_url}/deepin/ ${codename}-updates main commercial community
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 更新软件源缓存
    echo -e "${BLUE}正在更新软件源缓存...${PLAIN}"
    apt-get update
    echo -e "${SUCCESS} 软件源缓存更新完成"
}

# Linux Mint 换源
change_mint_source() {
    local mirror_url="$1"
    local source_file="/etc/apt/sources.list"

    backup_source "$source_file"

    # 获取 Mint 版本代号 (virginia, wilma, faye 等)
    local codename=$(lsb_release -cs 2>/dev/null)
    # Mint 基于 Ubuntu，需要获取对应的 Ubuntu 代号
    local ubuntu_codename=""
    case "$codename" in
        virginia|wilma|faye|xia) ubuntu_codename="noble" ;;    # Mint 22 基于 Ubuntu 24.04
        vera|victoria|vanessa)   ubuntu_codename="jammy" ;;    # Mint 21 基于 Ubuntu 22.04
        uma|una|ulyana|ulyssa)   ubuntu_codename="focal" ;;    # Mint 20 基于 Ubuntu 20.04
        tricia|tina|tara)        ubuntu_codename="bionic" ;;   # Mint 19 基于 Ubuntu 18.04
        *)                       ubuntu_codename="noble" ;;
    esac

    echo -e "${BLUE}正在生成 Linux Mint 软件源配置...${PLAIN}"
    echo -e "${SUCCESS} Mint 代号: ${codename}, Ubuntu 基础: ${ubuntu_codename}"

    # Linux Mint 需要配置 Mint 自己的源和 Ubuntu 的源
    cat > "$source_file" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: Linux Mint ${codename}

# Linux Mint 官方源
deb https://${mirror_url}/linuxmint/ ${codename} main upstream backport import

# Ubuntu 基础源 (Mint 依赖)
deb https://${mirror_url}/ubuntu/ ${ubuntu_codename} main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ ${ubuntu_codename}-updates main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ ${ubuntu_codename}-backports main restricted universe multiverse
deb https://${mirror_url}/ubuntu/ ${ubuntu_codename}-security main restricted universe multiverse
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 更新软件源缓存
    echo -e "${BLUE}正在更新软件源缓存...${PLAIN}"
    apt-get update
    echo -e "${SUCCESS} 软件源缓存更新完成"
}

# CentOS 7 换源
change_centos7_source() {
    local mirror_url="$1"
    local repo_dir="/etc/yum.repos.d"

    # 备份现有配置
    if [[ -d "$repo_dir" ]]; then
        local backup_dir="${repo_dir}.bak.$(date +%Y%m%d%H%M%S)"
        cp -r "$repo_dir" "$backup_dir"
        echo -e "${SUCCESS} 已备份源配置到: ${backup_dir}"
    fi

    echo -e "${BLUE}正在生成 CentOS 7 软件源配置...${PLAIN}"

    cat > "${repo_dir}/CentOS-Base.repo" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: CentOS 7

[base]
name=CentOS-7 - Base - ${mirror_url}
baseurl=https://${mirror_url}/centos/7/os/\$basearch/
gpgcheck=1
gpgkey=https://${mirror_url}/centos/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-7 - Updates - ${mirror_url}
baseurl=https://${mirror_url}/centos/7/updates/\$basearch/
gpgcheck=1
gpgkey=https://${mirror_url}/centos/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-7 - Extras - ${mirror_url}
baseurl=https://${mirror_url}/centos/7/extras/\$basearch/
gpgcheck=1
gpgkey=https://${mirror_url}/centos/RPM-GPG-KEY-CentOS-7

[centosplus]
name=CentOS-7 - Plus - ${mirror_url}
baseurl=https://${mirror_url}/centos/7/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://${mirror_url}/centos/RPM-GPG-KEY-CentOS-7
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 生成缓存
    echo -e "${BLUE}正在生成软件源缓存...${PLAIN}"
    yum makecache 2>/dev/null || dnf makecache 2>/dev/null
    echo -e "${SUCCESS} 软件源缓存生成完成"
}

# CentOS Stream 8/9/10 换源
change_centos_stream_source() {
    local mirror_url="$1"
    local repo_dir="/etc/yum.repos.d"
    local major_version=$(echo "${SYSTEM_VERSION_ID}" | cut -d. -f1)

    # 备份现有配置
    if [[ -d "$repo_dir" ]]; then
        local backup_dir="${repo_dir}.bak.$(date +%Y%m%d%H%M%S)"
        cp -r "$repo_dir" "$backup_dir"
        echo -e "${SUCCESS} 已备份源配置到: ${backup_dir}"
    fi

    echo -e "${BLUE}正在生成 CentOS Stream ${major_version} 软件源配置...${PLAIN}"

    cat > "${repo_dir}/centos.repo" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: CentOS Stream ${major_version}

[baseos]
name=CentOS Stream ${major_version} - BaseOS - ${mirror_url}
baseurl=https://${mirror_url}/centos-stream/${major_version}-stream/BaseOS/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[appstream]
name=CentOS Stream ${major_version} - AppStream - ${mirror_url}
baseurl=https://${mirror_url}/centos-stream/${major_version}-stream/AppStream/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[extras-common]
name=CentOS Stream ${major_version} - Extras packages - ${mirror_url}
baseurl=https://${mirror_url}/centos-stream/${major_version}-stream/extras/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 生成缓存
    echo -e "${BLUE}正在生成软件源缓存...${PLAIN}"
    dnf makecache
    echo -e "${SUCCESS} 软件源缓存生成完成"
}

# Rocky Linux 换源
change_rocky_source() {
    local mirror_url="$1"
    local repo_dir="/etc/yum.repos.d"
    local major_version=$(echo "${SYSTEM_VERSION_ID}" | cut -d. -f1)

    # 备份现有配置
    if [[ -d "$repo_dir" ]]; then
        local backup_dir="${repo_dir}.bak.$(date +%Y%m%d%H%M%S)"
        cp -r "$repo_dir" "$backup_dir"
        echo -e "${SUCCESS} 已备份源配置到: ${backup_dir}"
    fi

    echo -e "${BLUE}正在生成 Rocky Linux ${major_version} 软件源配置...${PLAIN}"

    cat > "${repo_dir}/rocky.repo" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: Rocky Linux ${major_version}

[baseos]
name=Rocky Linux ${major_version} - BaseOS - ${mirror_url}
baseurl=https://${mirror_url}/rocky/${major_version}/BaseOS/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky-${major_version}

[appstream]
name=Rocky Linux ${major_version} - AppStream - ${mirror_url}
baseurl=https://${mirror_url}/rocky/${major_version}/AppStream/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky-${major_version}

[extras]
name=Rocky Linux ${major_version} - Extras - ${mirror_url}
baseurl=https://${mirror_url}/rocky/${major_version}/extras/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rocky-${major_version}
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 生成缓存
    echo -e "${BLUE}正在生成软件源缓存...${PLAIN}"
    dnf makecache
    echo -e "${SUCCESS} 软件源缓存生成完成"
}

# AlmaLinux 换源
change_almalinux_source() {
    local mirror_url="$1"
    local repo_dir="/etc/yum.repos.d"
    local major_version=$(echo "${SYSTEM_VERSION_ID}" | cut -d. -f1)

    # 备份现有配置
    if [[ -d "$repo_dir" ]]; then
        local backup_dir="${repo_dir}.bak.$(date +%Y%m%d%H%M%S)"
        cp -r "$repo_dir" "$backup_dir"
        echo -e "${SUCCESS} 已备份源配置到: ${backup_dir}"
    fi

    echo -e "${BLUE}正在生成 AlmaLinux ${major_version} 软件源配置...${PLAIN}"

    cat > "${repo_dir}/almalinux.repo" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: AlmaLinux ${major_version}

[baseos]
name=AlmaLinux ${major_version} - BaseOS - ${mirror_url}
baseurl=https://${mirror_url}/almalinux/${major_version}/BaseOS/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-${major_version}

[appstream]
name=AlmaLinux ${major_version} - AppStream - ${mirror_url}
baseurl=https://${mirror_url}/almalinux/${major_version}/AppStream/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-${major_version}

[extras]
name=AlmaLinux ${major_version} - Extras - ${mirror_url}
baseurl=https://${mirror_url}/almalinux/${major_version}/extras/\$basearch/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-${major_version}
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 生成缓存
    echo -e "${BLUE}正在生成软件源缓存...${PLAIN}"
    dnf makecache
    echo -e "${SUCCESS} 软件源缓存生成完成"
}

# Fedora 换源
change_fedora_source() {
    local mirror_url="$1"
    local repo_dir="/etc/yum.repos.d"
    local version="${SYSTEM_VERSION_ID}"

    # 备份现有配置
    if [[ -d "$repo_dir" ]]; then
        local backup_dir="${repo_dir}.bak.$(date +%Y%m%d%H%M%S)"
        cp -r "$repo_dir" "$backup_dir"
        echo -e "${SUCCESS} 已备份源配置到: ${backup_dir}"
    fi

    echo -e "${BLUE}正在生成 Fedora ${version} 软件源配置...${PLAIN}"

    cat > "${repo_dir}/fedora.repo" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}
# System: Fedora ${version}

[fedora]
name=Fedora ${version} - ${mirror_url}
baseurl=https://${mirror_url}/fedora/releases/${version}/Everything/\$basearch/os/
enabled=1
metadata_expire=7d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${version}-\$basearch
skip_if_unavailable=False

[updates]
name=Fedora ${version} - Updates - ${mirror_url}
baseurl=https://${mirror_url}/fedora/updates/${version}/Everything/\$basearch/
enabled=1
metadata_expire=6h
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${version}-\$basearch
skip_if_unavailable=False

[updates-testing]
name=Fedora ${version} - Updates Testing - ${mirror_url}
baseurl=https://${mirror_url}/fedora/updates/testing/${version}/Everything/\$basearch/
enabled=0
metadata_expire=6h
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${version}-\$basearch
skip_if_unavailable=False
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 生成缓存
    echo -e "${BLUE}正在生成软件源缓存...${PLAIN}"
    dnf makecache
    echo -e "${SUCCESS} 软件源缓存生成完成"
}

# CentOS/RHEL 系换源 (统一入口)
change_yum_source() {
    local mirror_url="$1"
    local major_version=$(echo "${SYSTEM_VERSION_ID}" | cut -d. -f1)

    case "${SYSTEM_ID}" in
        centos)
            if [[ "$major_version" == "7" ]]; then
                change_centos7_source "$mirror_url"
            else
                change_centos_stream_source "$mirror_url"
            fi
            ;;
        rocky)
            change_rocky_source "$mirror_url"
            ;;
        almalinux)
            change_almalinux_source "$mirror_url"
            ;;
        fedora)
            change_fedora_source "$mirror_url"
            ;;
    esac
}

# Arch Linux 换源
change_arch_source() {
    local mirror_url="$1"
    local mirrorlist="/etc/pacman.d/mirrorlist"

    backup_source "$mirrorlist"

    echo -e "${BLUE}正在生成 Arch Linux 软件源配置...${PLAIN}"

    cat > "$mirrorlist" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}

Server = https://${mirror_url}/archlinux/\$repo/os/\$arch
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 同步软件源
    echo -e "${BLUE}正在同步软件源...${PLAIN}"
    pacman -Sy
    echo -e "${SUCCESS} 软件源同步完成"
}

# Alpine Linux 换源
change_alpine_source() {
    local mirror_url="$1"
    local repos="/etc/apk/repositories"

    backup_source "$repos"

    # 获取 Alpine 版本
    local version=$(cat /etc/alpine-release | cut -d. -f1,2)

    echo -e "${BLUE}正在生成 Alpine Linux 软件源配置...${PLAIN}"

    cat > "$repos" << EOF
# Generated by FastMirrors
# Mirror: ${mirror_url}

https://${mirror_url}/alpine/${version}/main
https://${mirror_url}/alpine/${version}/community
EOF

    echo -e "${SUCCESS} 已更新软件源配置"

    # 更新索引
    echo -e "${BLUE}正在更新软件源索引...${PLAIN}"
    apk update
    echo -e "${SUCCESS} 软件源索引更新完成"
}

# 设置镜像源
set_mirror() {
    local mirror_url="$1"

    if [[ -z "$mirror_url" ]]; then
        echo -e "${ERROR} 请指定镜像源地址"
        exit 1
    fi

    detect_system

    case "${SYSTEM_ID}" in
        debian)
            change_debian_source "$mirror_url"
            ;;
        ubuntu)
            change_ubuntu_source "$mirror_url"
            ;;
        kali)
            change_kali_source "$mirror_url"
            ;;
        deepin)
            change_deepin_source "$mirror_url"
            ;;
        linuxmint)
            change_mint_source "$mirror_url"
            ;;
        centos)
            change_yum_source "$mirror_url"
            ;;
        rocky)
            change_rocky_source "$mirror_url"
            ;;
        almalinux)
            change_almalinux_source "$mirror_url"
            ;;
        fedora)
            change_fedora_source "$mirror_url"
            ;;
        rhel)
            # RHEL 使用与 CentOS Stream 类似的配置
            change_yum_source "$mirror_url"
            ;;
        arch|manjaro)
            change_arch_source "$mirror_url"
            ;;
        alpine)
            change_alpine_source "$mirror_url"
            ;;
        *)
            echo -e "${ERROR} 不支持的系统类型: ${SYSTEM_ID}"
            echo -e "${WARN} 支持的系统: debian, ubuntu, kali, deepin, linuxmint, centos, rocky, almalinux, fedora, rhel, arch, manjaro, alpine"
            exit 1
            ;;
    esac
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

# 自动换源 (测速后选择最快的源)
auto_change_mirror() {
    echo -e "${BOLD}========================================${PLAIN}"
    echo -e "${BOLD}    Linux 软件源自动换源${PLAIN}"
    echo -e "${BOLD}========================================${PLAIN}"
    echo ""

    detect_system
    local source_file=$(get_source_file)

    # Step 1: 备份原始源
    echo -e "${BLUE}[Step 1] 备份原始软件源配置...${PLAIN}"
    if [[ -f "$source_file" ]]; then
        local backup_file="${source_file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$source_file" "$backup_file"
        echo -e "${SUCCESS} 已备份到: ${backup_file}"
    elif [[ -d "$source_file" ]]; then
        local backup_dir="${source_file}.bak.$(date +%Y%m%d%H%M%S)"
        cp -r "$source_file" "$backup_dir"
        echo -e "${SUCCESS} 已备份到: ${backup_dir}"
    else
        echo -e "${WARN} 未找到源配置文件，跳过备份"
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

    # 从更新后的 mirrors.txt 读取第一个镜像源
    local fastest_mirror=""
    while IFS='|' read -r url desc sys || [[ -n "$url" ]]; do
        [[ "$url" =~ ^#.*$ || -z "$url" ]] && continue
        fastest_mirror="$url"
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
    set_mirror "$fastest_mirror"

    echo ""
    echo -e "${GREEN}${BOLD}自动换源完成!${PLAIN}"
    echo -e "${BOLD}已更换为最快的镜像源: ${fastest_mirror}${PLAIN}"
}

# 显示当前配置
show_current() {
    detect_system
    local source_file=$(get_source_file)

    echo -e "${BOLD}当前软件源配置:${PLAIN}"
    echo ""

    if [[ -f "$source_file" ]]; then
        cat "$source_file"
    elif [[ -d "$source_file" ]]; then
        echo "源配置目录: ${source_file}"
        echo ""
        for repo in "$source_file"/*.repo; do
            if [[ -f "$repo" ]]; then
                echo -e "${GREEN}=== $(basename $repo) ===${PLAIN}"
                cat "$repo"
                echo ""
            fi
        done
    else
        echo "未找到源配置文件"
    fi
}


# 更新软件包
update_packages() {
    detect_system

    echo -e "${BLUE}正在更新软件包...${PLAIN}"

    case "${SYSTEM_ID}" in
        debian|ubuntu|kali|deepin|linuxmint)
            apt-get update && apt-get upgrade -y
            ;;
        centos|rhel|rocky|almalinux|fedora)
            yum update -y 2>/dev/null || dnf update -y 2>/dev/null
            ;;
        arch|manjaro)
            pacman -Syu --noconfirm
            ;;
        alpine)
            apk update && apk upgrade
            ;;
        *)
            echo -e "${ERROR} 不支持的系统类型: ${SYSTEM_ID}"
            exit 1
            ;;
    esac

    echo -e "${SUCCESS} 软件包更新完成"
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
            -u|--update)
                action="update"
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
            set_mirror "$mirror_url"
            ;;
        interactive)
            check_root
            interactive_select
            ;;
        auto)
            check_root
            auto_change_mirror
            ;;
        current)
            show_current
            ;;
        update)
            check_root
            set_mirror "$mirror_url"
            update_packages
            ;;
    esac
}

main "$@"
