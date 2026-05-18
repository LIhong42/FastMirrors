# FastMirrors - 快速换源工具集

一个简单高效的镜像源管理工具，支持 Docker、Linux 软件源和 pip 镜像源的自动搜索聚集，可用性测速与一键换源。

## 功能特性

- **全网镜像源聚合**：自动搜索全网可用镜像源，并进行连接测试和docker容器仿真测试 [https://github.com/LIhong42/mirror-source-extractor-skill](https://github.com/LIhong42/mirror-source-extractor-skill)
- **自动换源**: 自动测试镜像源速度，选择最快的源
- **交互式选择**: 提供交互式界面，手动选择镜像源
- **多系统支持**: 支持 Debian/Ubuntu/CentOS/Arch/Alpine 等主流 Linux 发行版
- **备份恢复**: 自动备份原有配置，支持一键恢复

---

## 可用镜像源

### Docker 镜像源

| 镜像地址 | 描述 |
|----------|------|
| `docker.jiaxin.site` | 简行镜像 |
| `docker.m.daocloud.io` | DaoCloud镜像站 |
| `proxy.vvvv.ee` | Docker离线镜像下载 |
| `dockerproxy.net` | Docker Proxy镜像加速 |
| `docker.1panel.live` | 1Panel镜像（限制只能中国地区） |
| `registry.cyou` | 容器镜像管理中心 |
| `docker.1ms.run` | 毫秒镜像 |

### Linux 软件源

#### 国内镜像源（推荐）

| 镜像地址 | 描述 | 适用系统 |
|----------|------|----------|
| `mirrors.aliyun.com` | 阿里云镜像 | all |
| `mirrors.tuna.tsinghua.edu.cn` | 清华大学镜像 | all |
| `mirrors.huaweicloud.com` | 华为云镜像 | all |
| `mirrors.cloud.tencent.com` | 腾讯云镜像 | all |
| `mirrors.nju.edu.cn` | 南京大学镜像 | all |
| `mirror.sjtu.edu.cn` | 上海交通大学镜像 | all |
| `mirrors.bfsu.edu.cn` | 北京外国语大学镜像 | all |
| `mirrors.jlu.edu.cn` | 吉林大学镜像 | all |
| `mirrors.pku.edu.cn` | 北京大学镜像 | all |
| `mirrors.ustc.edu.cn` | 中国科学技术大学镜像 | all |
| `mirrors.sustech.edu.cn` | 南方科技大学镜像 | all |
| `mirrors.cmecloud.cn` | 中国移动镜像 | all |
| `mirrors.hit.edu.cn` | 哈尔滨工业大学镜像 | all |
| `mirrors.nwafu.edu.cn` | 西北农林科技大学镜像 | all |
| `mirror.lzu.edu.cn` | 兰州大学镜像 | all |
| `mirrors.cernet.edu.cn` | 中国教育和科研计算机网镜像 | all |

#### 海外镜像源

| 镜像地址 | 描述 | 适用系统 |
|----------|------|----------|
| `mirrors.xtom.de` | 德国XTOM镜像 | all |
| `mirrors.xtom.nl` | 荷兰XTOM镜像 | all |
| `mirrors.xtom.us` | 美国XTOM镜像 | all |
| `mirrors.xtom.jp` | 日本XTOM镜像 | all |
| `mirrors.dotsrc.org` | 丹麦DotSrc镜像 | all |
| `mirror.sg.gs` | 新加坡镜像 | all |
| `mirror.01link.hk` | 香港01link镜像 | all |
| `mirror.yandex.ru` | 俄罗斯Yandex镜像 | all |
| `mirror.accum.se` | 瑞典Accum镜像 | all |
| `mirrors.ocf.berkeley.edu` | 伯克利大学镜像 | all |
| `ftp.udx.icscoe.jp/Linux` | 日本镜像 | all |
| `ftp.lysator.liu.se` | 瑞典Lysator镜像 | all |
| `mirrors.gbnetwork.com` | GBNetwork镜像 | all |

### pip 镜像源

| 镜像地址 | 描述 | 信任主机 |
|----------|------|----------|
| `pypi.tuna.tsinghua.edu.cn/simple` | 清华大学镜像 | `pypi.tuna.tsinghua.edu.cn` |
| `repo.huaweicloud.com/repository/pypi/simple` | 华为云镜像 | `repo.huaweicloud.com` |
| `mirrors.bfsu.edu.cn/pypi/web/simple` | 北京外国语大学镜像 | `mirrors.bfsu.edu.cn` |
| `mirrors.huaweicloud.com/repository/pypi/simple` | 华为云镜像(备用) | `mirrors.huaweicloud.com` |
| `mirrors.sustech.edu.cn/pypi/web/simple` | 南方科技大学镜像 | `mirrors.sustech.edu.cn` |
| `mirrors.cloud.tencent.com/pypi/simple` | 腾讯云镜像 | `mirrors.cloud.tencent.com` |
| `pypi.doubanio.com/simple` | 豆瓣镜像 | `pypi.doubanio.com` |
| `mirrors.westlake.edu.cn/pypi/simple` | 西湖大学镜像 | `mirrors.westlake.edu.cn` |
| `download.pytorch.org/whl` | PyTorch官方下载源 | `download.pytorch.org` |
| `mirrors.ustc.edu.cn/pypi/simple` | 中国科学技术大学镜像 | `mirrors.ustc.edu.cn` |
| `pypi.org/simple` | PyPI官方源(国际) | `pypi.org` |

---

## 使用方法

### 快速开始

```bash
# 克隆项目
git clone https://github.com/yourusername/FastMirrors.git
cd FastMirrors

# 运行主脚本
bash fast_mirrors.sh
```

### Docker 换源

```bash
# 交互式选择
bash fast_mirrors.sh docker -i

# 自动换源（测速后选择最快的3个）
bash fast_mirrors.sh docker-auto

# 列出所有可用镜像源
bash fast_mirrors.sh docker -l

# 设置指定镜像源
bash fast_mirrors.sh docker -s docker.1ms.run

# 查看当前配置
bash fast_mirrors.sh docker -c
```

### Linux 软件源换源

```bash
# 交互式选择
sudo bash fast_mirrors.sh linux -i

# 自动换源（测速后选择最快的）
sudo bash fast_mirrors.sh linux-auto

# 列出所有可用镜像源
bash fast_mirrors.sh linux -l

# 设置指定镜像源
sudo bash fast_mirrors.sh linux -s mirrors.aliyun.com
```

### pip 换源

```bash
# 交互式选择
bash fast_mirrors.sh pip -i

# 自动换源（测速后选择最快的）
bash fast_mirrors.sh pip-auto

# 全局配置（需要root权限）
sudo bash fast_mirrors.sh pip -g -i

# 列出所有可用镜像源
bash fast_mirrors.sh pip -l

# 设置指定镜像源
bash fast_mirrors.sh pip -s pypi.tuna.tsinghua.edu.cn/simple
```

### 一键换源

```bash
# 一键更换所有源（交互式）
bash fast_mirrors.sh all
```

---

## 支持的 Linux 系统

### Debian 系
- Debian 9-13 (stretch, buster, bullseye, bookworm, trixie)
- Ubuntu 14-26 (trusty, xenial, bionic, focal, jammy, noble)
- Kali Linux (kali-rolling)
- Deepin 20/23 (apricot, beige)
- Linux Mint 19-22

### RHEL 系
- CentOS 7
- CentOS Stream 8-10
- Rocky Linux 8-10
- AlmaLinux 8-10
- Fedora 30-43

### 其他
- Arch Linux / Manjaro
- Alpine Linux v3 / edge

---

## 项目结构

```
FastMirrors/
├── fast_mirrors.sh          # 主入口脚本
├── docker/
│   ├── change_mirror.sh     # Docker换源脚本
│   └── speed_test.sh        # Docker测速脚本
├── linux/
│   ├── change_mirror.sh     # Linux换源脚本
│   └── speed_test.sh        # Linux测速脚本
├── pip/
│   ├── change_mirror.sh     # pip换源脚本
│   └── speed_test.sh        # pip测速脚本
├── mirror-sources/
│   ├── docker.txt           # Docker镜像源列表
│   ├── linux.txt            # Linux软件源列表
│   └── pip.txt              # pip镜像源列表
└── log.md                   # 镜像源提取日志
```

---

## 致谢

本项目的镜像源信息来源于以下开源项目：

| 项目 | 描述 | GitHub链接 |
|------|------|------------|
| **SuperManito/LinuxMirrors** | GNU/Linux 更换系统软件源脚本及 Docker 安装与换源脚本 | [https://github.com/SuperManito/LinuxMirrors](https://github.com/SuperManito/LinuxMirrors) |
| **winrey/EasyConnectedInChina** | 汇总各种工具国内镜像源和设置镜像源的方法 | [https://github.com/winrey/EasyConnectedInChina](https://github.com/winrey/EasyConnectedInChina) |
| **adysec/mirror** | Cloudflare Workers镜像代理站 | [https://github.com/adysec/mirror](https://github.com/adysec/mirror) |
| **ox01024/cmirror** | Cmirror (China Mirror Manager) - 基于Rust编写的跨平台镜像管理命令行工具 | [https://github.com/ox01024/cmirror](https://github.com/ox01024/cmirror) |
| **NoCLin/LightMirrors** | 开源的缓存镜像站服务，用于加速软件包下载和镜像拉取 | [https://github.com/NoCLin/LightMirrors](https://github.com/NoCLin/LightMirrors) |
| **caoergou/cnpip** | 一个帮助快速切换 pip 镜像源的命令行工具 | [https://github.com/caoergou/cnpip](https://github.com/caoergou/cnpip) |
| **hrpzcf/AwesomePyKit** | Python工具箱，包含包管理器、镜像源设置工具 | [https://github.com/hrpzcf/AwesomePyKit](https://github.com/hrpzcf/AwesomePyKit) |

感谢以上项目及其贡献者提供的镜像源信息！

---

## License

MIT License