# AGENTS.md - AI Coding Agent Guide

> This file contains essential information for AI coding agents working on this project.
> 本文件包含供 AI 编程助手使用的项目关键信息。

## Project Overview / 项目概述

**clash-for-linux-install** 是一个用于在 Linux 系统上一键安装和配置 Clash/Mihomo 代理内核的 Shell 脚本项目。

主要功能：
- 支持一键安装 `mihomo` 与 `clash` 两种代理内核
- 兼容 `root` 与普通用户环境
- 适配主流 Linux 发行版，兼容容器化环境（如 AutoDL）
- 自动检测端口占用并随机分配可用端口
- 自动识别系统架构与初始化系统，下载匹配的二进制文件
- 支持本地订阅转换（subconverter）
- 提供 Web 控制台（zashboard）进行可视化操作

## Technology Stack / 技术栈

- **Language**: Bash (Shell Script)
- **Target Shells**: Bash, Zsh, Fish (partial support)
- **Init Systems**: systemd, OpenRC, SysVinit, runit, nohup (fallback)
- **Supported Architectures**: x86_64 (with v1/v2/v3 variants), i386, armv7, aarch64

### External Dependencies / 外部依赖

安装脚本依赖以下系统命令：
- `xz` - 压缩/解压
- `pgrep` - 进程查询
- `curl` 或 `wget` - 网络下载
- `tar` - 归档解压
- `unzip` - ZIP 解压
- `ss` 或 `netstat` - 端口检测
- `ip` 或 `hostname` - IP 地址获取

### Bundled Binaries / 捆绑的二进制程序

安装过程中会下载以下组件：
- **mihomo/clash** - 代理内核（GitHub Releases）
- **yq** - YAML 处理工具
- **subconverter** - 订阅转换服务
- **dist.zip** - Web UI（zashboard）

## Project Structure / 项目结构

```
clash-for-linux-install/
├── install.sh              # 主安装脚本入口
├── uninstall.sh            # 卸载脚本
├── .env                    # 默认配置文件（含版本号等）
├── .editorconfig           # 编辑器配置（2空格缩进）
├── .shellcheckrc           # ShellCheck 禁用规则
├── scripts/
│   ├── preflight.sh        # 安装前检查与准备逻辑
│   ├── cmd/
│   │   ├── clashctl.sh     # 核心命令实现（740+ 行）
│   │   ├── common.sh       # 公共函数与工具
│   │   └── clashctl.fish   # Fish shell 支持
│   └── init/
│       ├── systemd.sh      # systemd 服务模板
│       ├── SysVinit.sh     # SysVinit 服务脚本
│       ├── OpenRC.sh       # OpenRC 服务脚本
│       └── runit.sh        # runit 服务脚本
└── resources/
    ├── mixin.yaml          # Mixin 配置模板
    ├── profiles.yaml       # 订阅管理元数据
    ├── Country.mmdb        # GeoIP 数据库
    ├── geosite.dat         # GeoSite 数据库
    ├── preview.png         # README 预览图
    ├── profiles/           # 订阅配置文件存储目录
    └── zip/                # 下载的二进制压缩包存放目录
```

## Key Configuration Files / 关键配置文件

### .env 文件

安装配置默认值：

```bash
KERNEL_NAME=mihomo              # 可选：mihomo、clash
CLASH_BASE_DIR=~/clashctl       # 安装路径
CLASH_CONFIG_URL=               # 机场订阅链接
CLASH_SUB_UA=clash-verge/v2.4.0 # 下载订阅时的 User-Agent
INIT_TYPE=                      # 自动识别
ZIP_UI=resources/zip/dist.zip   # Web UI 压缩包
URL_GH_PROXY=https://gh-proxy.org  # GitHub 加速代理
URL_CLASH_UI=http://board.zash.run.place  # 公共 Web 控制台
VERSION_MIHOMO=v1.19.17         # mihomo 版本
VERSION_YQ=v4.49.2              # yq 版本
VERSION_SUBCONVERTER=v0.9.0     # subconverter 版本
```

### resources/mixin.yaml

Mixin 配置模板，支持与原始订阅配置深度合并：

- `_custom.system-proxy.enable` - 系统代理开关
- `mixed-port` - 混合代理端口（默认 7890）
- `external-controller` - Web API 地址（默认 0.0.0.0:9090）
- `rules.prefix/suffix/override` - 规则自定义
- `proxies.prefix/suffix/override` - 节点自定义
- `proxy-groups.prefix/suffix/override` - 策略组自定义
- `tun` - Tun 模式配置
- `dns` - DNS 配置

## Code Organization / 代码组织

### 模块化设计

1. **install.sh** - 安装入口
   - 加载 clashctl.sh 和 preflight.sh
   - 调用验证、解析参数、准备资源、检测 init 系统
   - 执行安装流程

2. **scripts/preflight.sh** - 安装准备
   - `_valid_required()` - 检查必需命令
   - `_valid()` - 验证安装环境
   - `_parse_args()` - 解析命令行参数
   - `_prepare_zip()` - 准备/下载二进制压缩包
   - `_detect_init()` - 检测并配置 init 系统
   - `_install_service()` - 安装系统服务
   - `_apply_rc()` - 配置 shell 启动脚本

3. **scripts/cmd/clashctl.sh** - 核心命令
   - `clashon/clashoff` - 开启/关闭代理
   - `clashstatus` - 查看内核状态
   - `clashproxy` - 系统代理控制
   - `clashui` - 显示 Web 控制台地址
   - `clashsecret` - Web 密钥管理
   - `clashtun` - Tun 模式控制
   - `clashmixin` - Mixin 配置管理
   - `clashsub` - 订阅管理
   - `clashupgrade` - 内核升级
   - `clashctl` - 统一命令入口

4. **scripts/cmd/common.sh** - 公共函数
   - 路径和文件变量定义
   - 端口检测与随机分配
   - 配置验证与下载
   - 订阅转换服务管理
   - 日志输出函数（`_okcat`, `_failcat`, `_error_quit`）

### 命名约定

- 函数命名：小写下划线分隔（`clashon`, `_valid_config`）
- 内部函数：以下划线开头（`_okcat`, `_merge_config`）
- 变量命名：大写（环境变量/全局）、小写（局部）
- 常量/配置：全大写下划线分隔

## Shell Style Guidelines / Shell 代码规范

### 格式规范

- 缩进：2 个空格（通过 .editorconfig 配置）
- 行尾：LF（Unix 风格）
- 函数定义使用 `function name()` 或 `name()` 语法

### 代码规范

```bash
# 推荐写法
local var="value"           # 局部变量声明
command -v cmd >&/dev/null  # 命令存在检查
[[ $var == "value" ]]       # 条件判断使用 [[ ]]
((count++))                 # 算术运算

# 字符串引用
"$variable"                 # 变量引用使用双引号
'literal string'            # 字面量使用单引号

# 函数返回
return 0                    # 成功
return 1                    # 失败
```

### ShellCheck 规则

项目禁用的 ShellCheck 规则（.shellcheckrc）：
- `SC1091` - 无法跟随源文件
- `SC2155` - 声明与赋值同时进行
- `SC2296` - 参数扩展中的可疑字符
- `SC2153` - 可能的大小写错误

## Build and Installation / 构建与安装

### 本地安装测试

```bash
# 克隆仓库
git clone --branch master --depth 1 https://github.com/nelvko/clash-for-linux-install.git
cd clash-for-linux-install

# 执行安装
bash install.sh

# 或使用参数
bash install.sh mihomo "https://your-subscription-url"
```

### 安装参数

- `mihomo` / `clash` - 指定内核类型
- `http(s)://...` - 订阅链接

### 调试

```bash
# 启用 Bash 调试模式
bash -x install.sh

# 查看安装日志
cat /var/log/mihomo.log   # root 用户
# 或
cat ~/clashctl/resources/mihomo.log  # 普通用户
```

## Testing / 测试

### 手动测试清单

安装后执行以下命令验证功能：

```bash
clashctl --help            # 查看帮助
clashon                    # 开启代理
clashstatus                # 检查状态
clashproxy                 # 查看系统代理
clashui                    # 查看 Web 控制台地址
clashsub ls                # 查看订阅列表
clashmixin                 # 查看 Mixin 配置
clashtun                   # 查看 Tun 状态
clashoff                   # 关闭代理
```

### 卸载

```bash
bash uninstall.sh
```

## Security Considerations / 安全注意事项

1. **权限控制**
   - Tun 模式需要 root 权限
   - 普通用户安装时 init 类型降级为 `nohup`
   - 安装路径避免使用 `/root/*` 当使用 sudo 执行时

2. **密钥管理**
   - Web 控制台默认使用随机密钥
   - 可通过 `clashsecret` 修改密钥
   - 建议公网访问时定期更换密钥

3. **认证配置**
   - `allow-lan: true` 时务必设置 `authentication`
   - 避免代理服务被未授权访问

4. **订阅安全**
   - 订阅链接包含敏感信息，避免泄露
   - 日志中已屏蔽订阅内容

## Development Workflow / 开发工作流

### 代码修改流程

1. 修改脚本文件
2. 使用 ShellCheck 检查语法
3. 本地测试安装/卸载流程
4. 验证所有 clashctl 命令正常工作

### Issue 模板

项目使用 GitHub Issue 模板：
- Bug 报告（.github/ISSUE_TEMPLATE/bug_report.yml）
- 功能请求（.github/ISSUE_TEMPLATE/feat_report.yml）
- 问答（.github/ISSUE_TEMPLATE/q&a.yml）

### 自动化任务

- Stale Issues 自动关闭（每周一至五 9:00 运行）
- 7 天标记 stale，再 7 天后关闭
- 带有 bug/documentation/enhancement 标签的 Issue 不受影响

## Internationalization / 国际化

项目主要面向中文用户：
- 代码注释使用中文
- 用户界面输出使用中文
- README 使用中文
- 日志和错误信息使用中文

## References / 参考资料

- [Clash 文档](https://clash.wiki/)
- [Mihomo 项目](https://github.com/MetaCubeX/mihomo)
- [subconverter](https://github.com/tindy2013/subconverter)
- [yq](https://github.com/mikefarah/yq)
- [zashboard](https://github.com/Zephyruso/zashboard)

---

*Last updated: 2026-03-24*
