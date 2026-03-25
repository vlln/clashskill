# clashctl

> 轻量级 Linux 代理管理工具 | Unix 设计 | 为 AI Agent 优化

[![License](https://img.shields.io/github/license/nelvko/clash-for-linux-install)](LICENSE)
[![Shell](https://img.shields.io/badge/language-Shell-89e051)](.)

**152KB** 极致轻量，**为 AI Agent 优化**，**可装为 Agent Skill 自动触发。**

## 设计特色

| 特色 | 说明 |
|------|------|
| **AI Skill 友好** | 完整命令树、结构化 ID（#n @n）、配置路径输出、程序化配置 |
| **Unix 哲学** | 一个命令做一件事，通过组合实现复杂能力 |
| **语义化分类** | proxy/node/net/sub/sys 等名词命令，直观易记 |

### 为 AI Agent 优化的功能

- **命令树视觉化** - `──` 树形结构，AI 可直接解析命令层级
- **配置路径输出** - `clashctl rules --path` 直接返回配置文件路径，无需解析输出
- **结构化 ID** - `#1` 策略组、`@3` 节点，AI 可精确引用
- **程序化配置** - `clashctl rules set "yaml"` 直接传入配置，无需交互编辑器
- **Skill 支持** - 可装为 Kimi Skill，自动触发提供命令帮助

## 安装

```bash
git clone --depth 1 https://github.com/vlln/clashskill.git
```

## 命令结构

```
clashctl <命令> [子命令] [options]

命令树:
clashctl
├── proxy        代理核心
│   ├── on          开启代理
│   ├── off         关闭代理
│   ├── status      查看状态
│   ├── mode        切换模式
│   │   ├── rule    规则模式
│   │   ├── global  全局模式
│   │   └── direct  直连模式
│   └── sys         系统代理开关（全局生效）
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
├── rules        规则配置
│   ├── edit        编辑全局配置
│   ├── set         直接设置配置（Agent友好）
│   ├── on          启用自动应用
│   ├── off         禁用自动应用
│   └── status      查看状态
├── tun          Tun 模式
│   ├── on          开启 Tun
│   ├── off         关闭 Tun
│   └── status      查看状态
├── web          Web 控制台
│   └── secret      密钥管理
│           └── --set   设置新密钥
└── sys          系统维护
    ├── upgrade     升级内核
    └── log         查看日志
```

## 实际应用场景

通过 `clashctl rules` 全局配置，设置一次即可在所有新订阅/合并中自动生效。

### 场景1：自定义 DNS（Tailscale + 公司内网）

```bash
# 配置多 DNS 服务器和域名策略
clashctl rules set "
dns:
  enable: true
  nameserver:
    - 100.100.100.100    # Tailscale DNS
    - 10.0.0.1           # 公司内网 DNS
    - 223.5.5.5          # 阿里云 DNS（兜底）
  nameserver-policy:
    'corp.company.com': 10.0.0.1
    'ts.net': 100.100.100.100
"

clashctl rules on    # 启用自动应用
```

### 场景2：GitHub 直连规则补充

```bash
# 方式一：直接设置
clashctl rules set "
rules:
  - DOMAIN-KEYWORD,github,DIRECT
  - DOMAIN-SUFFIX,github.com,DIRECT
  - DOMAIN-SUFFIX,githubusercontent.com,DIRECT
"

# 方式二：从文件导入
cat > ~/my-rules.yaml << 'EOF'
rules:
  - DOMAIN-KEYWORD,github,DIRECT
  - DOMAIN-SUFFIX,github.com,DIRECT
EOF

clashctl rules set -f ~/my-rules.yaml
clashctl rules on
```

### 场景3：Cloudflare WARP 链式代理

```bash
# 添加 WARP 节点并设置代理链
clashctl rules set "
proxies:
  - name: WARP
    type: wireguard
    server: engage.cloudflareclient.com
    port: 2408
    private-key: YOUR_PRIVATE_KEY
    public-key: bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
    reserved: [0, 0, 0]
    mtu: 1280

proxy-groups:
  - name: 🚀 代理链
    type: relay
    proxies:
      - 🚀 节点选择    # 原订阅的代理组
      - WARP              # WARP 作为出口

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

## 开源许可

本项目基于 [GNU General Public License v3.0](LICENSE) 开源许可。

## 致谢

感谢 [nelvko/clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install/tree/master) 原项目的贡献。
