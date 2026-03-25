---
name: clashctl-usage
description: Clashctl 轻量级 Linux 代理管理工具使用指南。提供完整的命令树结构、常用操作示例和配置说明。当用户需要了解或使用 clashctl 工具管理代理时触发此 skill。
---

# Clashctl 使用指南

> 轻量级 Linux 代理管理工具 | Unix 设计 | Agent 原生支持

## 快速开始

```bash
# 安装
git clone --depth 1 https://github.com/nelvko/clash-for-linux-install.git \
  && cd clash-for-linux-install \
  && bash install.sh

# 开启代理
clashctl proxy on

# 切换全局模式
clashctl proxy mode global

# 查看节点并切换
clashctl node ls
clashctl node use #1 @3
```

## 命令树

```
clashctl
├── proxy        代理核心
│   ├── on          开启代理（全局生效）
│   ├── off         关闭代理
│   ├── status      查看状态
│   ├── mode        切换模式
│   │   ├── rule    规则模式
│   │   ├── global  全局模式
│   │   └── direct  直连模式
│   └── sys         系统代理开关
├── node         节点管理
│   ├── ls          列出节点(#n)和策略组(@n)
│   ├── use         切换节点
│   └── test        测试节点延迟
│       ├── --all   测试所有节点
│       └── --sort  按延迟排序
├── net          网络诊断
│   ├── ping        网络连通测试
│   ├── dns         DNS 解析测试
│   ├── traffic     流量统计
│   └── conn        连接统计
├── test         网络测试
│   ├── network     完整网络诊断
│   ├── dns         DNS 解析
│   ├── delay       测试策略组节点延迟
│   └── nodes       测试所有节点并排序
├── sub          订阅管理
│   ├── add         添加订阅
│   ├── ls          列出订阅
│   ├── use         使用订阅
│   ├── update      更新订阅
│   ├── del         删除订阅
│   └── merge       融合订阅
├── rules        规则配置（全局配置）
│   ├── --path      运行时配置路径（Agent友好）
│   ├── --global    全局配置路径
│   ├── --base      原始订阅配置路径
│   ├── edit        编辑全局配置
│   ├── set         直接设置配置
│   ├── on          启用自动应用
│   ├── off         禁用自动应用
│   └── status      查看状态
├── tun          Tun 模式
│   ├── on          开启 Tun
│   ├── off         关闭 Tun
│   └── status      查看状态
├── web          Web 控制台
│   └── secret      密钥管理
│       └── --set   设置新密钥
└── sys          系统维护
    ├── upgrade     升级内核
    └── log         查看日志
```

## 常用操作

### 代理控制

```bash
clashctl proxy on                   # 开启代理
clashctl proxy off                  # 关闭代理
clashctl proxy status               # 查看状态
clashctl proxy mode rule            # 规则模式
clashctl proxy mode global          # 全局模式
clashctl proxy sys on               # 开启系统代理（全局生效）
```

### 节点管理

```bash
clashctl node ls                    # 列出策略组(#n)和节点(@n)
clashctl node use #1 @3             # 策略组#1 切换到节点@3
clashctl node test #1               # 测试当前节点延迟
clashctl node test #1 --all         # 测试策略组下所有节点
clashctl node test #1 --all --sort  # 测试并按延迟排序
```

### 订阅管理

```bash
clashctl sub add "https://..."      # 添加订阅
clashctl sub ls                     # 列出订阅
clashctl sub use 1                  # 使用订阅
clashctl sub update                 # 更新订阅
clashctl sub del 1                  # 删除订阅
clashctl sub merge 1 2 3 -o "融合"  # 融合订阅
```

### 网络诊断

```bash
clashctl net ping                   # 完整网络诊断
clashctl net ping --proxy           # 只测试代理
clashctl net ping --direct          # 只测试直连
clashctl net dns www.google.com     # DNS 解析测试
clashctl net traffic                # 流量统计
clashctl net conn                   # 连接统计
```

### 全局配置（Agent友好）

```bash
# 查看配置路径
clashctl rules --path               # 运行时配置路径
clashctl rules --global --path      # 全局配置路径

# 编辑配置
clashctl rules edit                 # 编辑全局配置
clashctl rules set "yaml: content"  # 直接设置配置
clashctl rules set -f /path/file    # 从文件设置配置

# 启用自动应用（新订阅自动生效）
clashctl rules on
clashctl rules off
```

## 实际应用场景

### 场景1：自定义 DNS

```bash
clashctl rules set "
dns:
  enable: true
  nameserver:
    - 100.100.100.100    # Tailscale DNS
    - 10.0.0.1           # 公司内网 DNS
"
clashctl rules on
```

### 场景2：GitHub 直连

```bash
clashctl rules set "
rules:
  - DOMAIN-KEYWORD,github,DIRECT
  - DOMAIN-SUFFIX,github.com,DIRECT
"
clashctl rules on
```

### 场景3：WARP 链式代理

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

## Unix 组合示例

```bash
# 定时测试并选择最优节点
clashctl node test #1 --all --sort | head -5

# 实时监控流量
watch -n 1 'clashctl net traffic'

# 批量更新所有订阅
for id in $(clashctl sub ls | grep -o '^[0-9]'); do clashctl sub update $id; done
```

## 配置

```bash
# ~/.config/clashctl/.env
KERNEL_NAME=mihomo
CLASH_BASE_DIR=~/clashctl
URL_GH_PROXY=https://gh-proxy.org
TEST_URL=http://www.gstatic.com/generate_204
TEST_TIMEOUT=5000
```

## 卸载

```bash
sudo systemctl stop clash 2>/dev/null; pkill -f mihomo 2>/dev/null; rm -rf ~/clashctl ~/.config/clashctl ~/.proxy.env
```

## 设计特点

| 原则 | 说明 |
|------|------|
| **Unix 哲学** | 一个命令做一件事，通过组合实现复杂能力 |
| **语义化分类** | proxy/node/net/sub/sys 等名词命令 |
| **Agent 友好** | 结构化 ID（#n @n）、配置路径输出、程序化接口 |
