# FastMirrors - 快速换源工具集

一个简单易用的 Linux/Docker/pip 镜像源自动切换工具，参考 [LinuxMirrors](https://github.com/SuperManito/LinuxMirrors) 项目设计实现。

## 功能特性

- **Docker 镜像源切换**: 自动更换 Docker Registry 镜像加速器
- **Linux 软件源切换**: 支持 Debian/Ubuntu/CentOS/Arch/Alpine 等主流发行版
- **pip 镜像源切换**: 快速切换 Python pip 镜像源
- **交互式选择**: 提供友好的交互式界面选择镜像源
- **速度测试**: 自动测试镜像源连接速度并排序
- **配置备份**: 自动备份原有配置，支持一键恢复

## 目录结构

```
fast_mirrors/
├── fast_mirrors.sh          # 主入口脚本
├── docker/
│   ├── mirrors.txt          # Docker 镜像源列表
│   └── change_mirror.sh     # Docker 换源脚本
├── linux/
│   ├── mirrors.txt          # Linux 软件源列表
│   └── change_mirror.sh     # Linux 换源脚本
└── pip/
    ├── mirrors.txt          # pip 镜像源列表
    └── change_mirror.sh     # pip 换源脚本
```

## 快速开始

### 一键换源

```bash
# 交互式更换所有源
./fast_mirrors.sh all
```

### Docker 镜像源

```bash
# 交互式选择镜像源
./fast_mirrors.sh docker -i

# 列出所有可用镜像源
./fast_mirrors.sh docker -l

# 设置指定镜像源
sudo ./fast_mirrors.sh docker -s docker.1ms.run

# 测试镜像源速度
./fast_mirrors.sh docker -t

# 查看当前配置
./fast_mirrors.sh docker -c

# 恢复备份配置
sudo ./fast_mirrors.sh docker -r
```

### Linux 软件源

```bash
# 交互式选择镜像源 (需要 root 权限)
sudo ./fast_mirrors.sh linux -i

# 列出所有可用镜像源
./fast_mirrors.sh linux -l

# 设置指定镜像源
sudo ./fast_mirrors.sh linux -s mirrors.aliyun.com

# 测试镜像源速度
./fast_mirrors.sh linux -t

# 查看当前配置
./fast_mirrors.sh linux -c
```

### pip 镜像源

```bash
# 交互式选择镜像源
./fast_mirrors.sh pip -i

# 列出所有可用镜像源
./fast_mirrors.sh pip -l

# 设置指定镜像源
./fast_mirrors.sh pip -s pypi.tuna.tsinghua.edu.cn/simple

# 全局设置镜像源 (需要 root 权限)
sudo ./fast_mirrors.sh pip -g -i

# 测试镜像源速度
./fast_mirrors.sh pip -t

# 查看当前配置
./fast_mirrors.sh pip -c

# 恢复默认配置
./fast_mirrors.sh pip -r
```

## 支持的系统

### Linux 软件源

| 系统 | 支持版本 |
|------|----------|
| Debian | 8 ~ 13 |
| Ubuntu | 14 ~ 26 |
| Kali Linux | all |
| Linux Mint | 17 ~ 22 |
| Deepin | all |
| CentOS | 7 ~ 8 / Stream 8 ~ 10 |
| Rocky Linux | 8 ~ 10 |
| AlmaLinux | 8 ~ 10 |
| Fedora | 30 ~ 43 |
| Arch Linux | all |
| Manjaro | all |
| Alpine Linux | v3 / edge |

## 镜像源列表

### Docker 镜像源

- 毫秒镜像 (docker.1ms.run)
- DaoCloud 镜像 (docker.m.daocloud.io)
- 阿里云镜像 (registry.cn-*.aliyuncs.com)
- 腾讯云镜像 (mirror.ccs.tencentyun.com)
- 更多见 `docker/mirrors.txt`

### Linux 软件源

- 阿里云镜像
- 腾讯云镜像
- 华为云镜像
- 清华大学镜像
- 中科大镜像
- 更多见 `linux/mirrors.txt`

### pip 镜像源

- 清华大学镜像
- 阿里云镜像
- 中科大镜像
- 腾讯云镜像
- 华为云镜像
- 更多见 `pip/mirrors.txt`

## 自定义镜像源

可以在对应的 `mirrors.txt` 文件中添加自定义镜像源，格式如下：

```
镜像地址|描述|其他参数
```

例如：

```
# Docker 镜像源
docker.example.com|示例镜像源

# Linux 软件源
mirrors.example.com|示例镜像站|all

# pip 镜像源
pypi.example.com/simple|示例 pip 源|pypi.example.com
```

## 参考

本项目参考了以下开源项目：

- [LinuxMirrors](https://github.com/SuperManito/LinuxMirrors) - GNU/Linux 更换系统软件源脚本及 Docker 安装与换源脚本

## License

MIT License
