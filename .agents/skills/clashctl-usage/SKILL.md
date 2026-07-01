---
name: clashctl-usage
description: 当用户需要了解或使用 clashctl 工具管理 Linux 代理时使用此 skill。覆盖代理开关、节点切换、订阅管理、规则配置和网络诊断等场景。
license: MIT
metadata:
  author: vlln
  version: "0.1.0"
requires:
  bins:
    - clashctl
---

# Clashctl 使用指南

## Trigger Keywords

clashctl, clash, mihomo, 代理, proxy, 节点, 订阅, 规则, 全局模式, Tun, 系统代理, 翻墙, VPN, 科学上网

## Capabilities

clashctl 是 Linux 代理管理工具，提供以下能力：

- **代理控制**：开关代理、切换模式（规则/全局/直连）、系统代理设置
- **节点管理**：列出策略组和节点、切换节点、延迟测试
- **订阅管理**：添加/删除/更新/融合订阅
- **网络诊断**：连通性测试、DNS 解析、流量与连接统计
- **规则配置**：编辑全局 Mixin 配置，与订阅配置深度合并，支持自动应用
- **Tun 模式**：虚拟网卡代理，需 root 权限
- **Web 控制台**：密钥管理

## Command Reference

```
clashctl
├── proxy    on|off|status|mode {rule|global|direct}|sys {on|off}
├── node     ls|use|test [--all] [--sort]
├── net      ping [--proxy|--direct]|dns <domain>|traffic|conn
├── test     network|dns|delay|nodes
├── sub      add <url>|ls|use <id>|update|del <id>|merge <ids> -o <name>
├── rules    edit|set <yaml>|on|off|status [--path|--global|--base]
├── tun      on|off|status
├── web      secret [--set <key>]
└── sys      upgrade|log
```

## Quick Start

```bash
clashctl proxy on                    # 开启代理
clashctl proxy mode global           # 切换全局模式
clashctl node ls                     # 查看节点
clashctl node use #1 @3              # 策略组#1 切换到节点@3
```

## Common Workflows

### 代理控制

```bash
clashctl proxy on
clashctl proxy off
clashctl proxy status
clashctl proxy mode rule|global|direct
clashctl proxy sys on                # 系统代理（影响所有应用）
```

### 节点管理

```bash
clashctl node ls                     # 列出策略组(#n)和节点(@n)
clashctl node use #1 @3              # 切换节点
clashctl node test #1                # 测试当前节点延迟
clashctl node test #1 --all --sort   # 测试所有节点并按延迟排序
```

### 订阅管理

```bash
clashctl sub add "https://..."
clashctl sub ls
clashctl sub use 1
clashctl sub update
clashctl sub del 1
clashctl sub merge 1 2 3 -o "融合"
```

### 网络诊断

```bash
clashctl net ping                    # 代理 + 直连双通道诊断
clashctl net ping --proxy            # 仅代理通道
clashctl net dns www.google.com
clashctl net traffic
clashctl net conn
```

### 规则配置（Mixin）

Mixin 配置与订阅原始配置深度合并。`rules on` 后每次订阅更新都会自动重新应用。

```bash
clashctl rules edit                  # 编辑器打开全局配置
clashctl rules set "yaml: content"   # 直接设置
clashctl rules set -f /path/file     # 从文件设置
clashctl rules on                    # 启用自动应用
clashctl rules off
clashctl rules --path                # 查看运行时配置路径
```

### 场景：自定义 DNS

```bash
clashctl rules set "
dns:
  enable: true
  nameserver:
    - 100.100.100.100
    - 10.0.0.1
"
clashctl rules on
```

### 场景：GitHub 直连

```bash
clashctl rules set "
rules:
  - DOMAIN-KEYWORD,github,DIRECT
  - DOMAIN-SUFFIX,github.com,DIRECT
"
clashctl rules on
```

### 场景：WARP 链式代理

```bash
clashctl rules set "
proxies:
  - name: WARP
    type: wireguard
    server: engage.cloudflareclient.com
    port: 2408

proxy-groups:
  - name: 🚀 代理链
    type: relay
    proxies:
      - 🚀 节点选择
      - WARP

rules:
  - MATCH,🚀 代理链
"
clashctl rules on
```

## Config

```bash
# ~/.config/clashctl/.env
KERNEL_NAME=mihomo
CLASH_BASE_DIR=~/clashctl
URL_GH_PROXY=https://gh-proxy.org
TEST_URL=http://www.gstatic.com/generate_204
TEST_TIMEOUT=5000
```

## Uninstall

```bash
sudo systemctl stop clash 2>/dev/null; pkill -f mihomo 2>/dev/null; rm -rf ~/clashctl ~/.config/clashctl ~/.proxy.env
```

## Gotchas

- **Root vs 普通用户**：Tun 模式需要 root 权限；普通用户安装时 init 系统降级为 nohup，代理不会开机自启。
- **`rules set` 必须提供合法 YAML**：命令不校验 YAML 语法，错误格式会覆盖配置导致代理异常。建议先 `rules edit` 在编辑器中校验。
- **端口冲突**：安装时自动检测端口占用，若 7890/9090 被占用会自动分配随机端口。使用 `clashctl proxy status` 确认实际端口。
- **订阅更新失败**：订阅链接可能因 GFW 无法直接访问，需配置 `URL_GH_PROXY` 代理。
- **Mixin 合并行为**：`rules set` 写入的是 Mixin 配置，与原始订阅配置深度合并。`rules on` 开启后每次订阅更新都会重新应用。
- **节点 ID 格式**：`#n` 表示策略组序号，`@n` 表示节点在该策略组内的序号。序号从 1 开始。
- **密钥安全**：Web 控制台默认使用随机密钥，公网环境务必通过 `clashctl web secret --set` 修改并定期更换。