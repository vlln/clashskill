<h1 align="center">clashctl</h1>

<p align="center">
  <strong>轻量级 Linux 代理管理工具，为 AI Agent 优化。</strong><br/>
  一键安装 Mihomo/Clash 代理内核，提供语义化命令行接口管理代理开关、节点切换、订阅更新、规则配置和网络诊断。支持 Tun 模式、Web 控制台和系统代理，兼容主流 Linux 发行版与容器化环境。
</p>

<p align="center">
  <a href="https://github.com/vlln/clashskill/stargazers"><img src="https://badgen.net/github/stars/vlln/clashskill?label=%E2%98%85" alt="GitHub stars" /></a>
  <img src="https://badgen.net/badge/license/GPL--3.0/blue" alt="GPL-3.0" />
  <img src="https://badgen.net/badge/spec/Agent%20Skills/8257D0" alt="Agent Skills spec" />
</p>

---

## Installation

### [skit](https://github.com/vlln/skit) (Recommended)

```bash
skit install https://github.com/vlln/clashskill/tree/main/.agents/skills/clashctl-usage
```

### Manually

| Agent | Command |
|-------|---------|
| **Claude Code** | `cp -r .agents/skills/clashctl-usage .claude/skills/` |
| **Codex** | `cp -r .agents/skills/clashctl-usage ~/.codex/skills/` |
| **OpenCode** | `git clone https://github.com/vlln/clashskill.git ~/.opencode/skills/clashskill` |
| **Kimi** | `cp -r .agents/skills/clashctl-usage ~/.kimi/skills/` |

---

## Skills

| Skill | Description |
|-------|-------------|
| [clashctl-usage](.agents/skills/clashctl-usage/SKILL.md) | 覆盖代理开关、节点切换、订阅管理、规则配置和网络诊断等场景。 |

## Requirements

- Linux (x86_64, i386, armv7, aarch64)
- 系统依赖：`xz`, `pgrep`, `curl`/`wget`, `tar`, `unzip`, `gzip`, `shuf`, `mktemp`, `ss`/`netstat`, `ip`/`hostname`
- Tun 模式需要 root 权限

## License

[GPL-3.0](LICENSE)

---

## 工具安装

```bash
git clone --depth 1 https://github.com/vlln/clashskill.git
cd clashskill && bash install.sh
```

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
- **Skill 支持** - 可装为 Agent Skill，自动触发提供命令帮助

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
│       └── --set   设置新密钥
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
URL_GH_PROXY=                    # 按需配置 GitHub 代理
TEST_URL=http://www.gstatic.com/generate_204
TEST_TIMEOUT=5000
```

## 卸载

```bash
bash uninstall.sh
```

## 注意事项

- **Root vs 普通用户**：Tun 模式需要 root 权限；普通用户安装时 init 系统降级为 nohup，代理可能不会开机自启。
- **`rules set` 必须提供合法 YAML**：命令会先校验 YAML，校验失败不会覆盖现有全局配置。
- **端口冲突**：安装时自动检测端口占用，若 7890/9090 被占用会自动分配随机端口。使用 `clashctl proxy status` 确认实际端口。
- **订阅更新失败**：订阅链接可能因网络问题（GFW）无法直接访问，需配置 `URL_GH_PROXY` 代理。
- **全局配置合并行为**：`rules set` 写入 `resources/extend.yaml`，会与内部 Mixin 和原始订阅配置合并。`rules off` 会让该全局配置在后续合并中失效。
- **节点 ID 格式**：`#n` 表示策略组序号，`@n` 表示节点在该策略组内的序号。序号从 1 开始，`clashctl node ls` 查看当前序号。
- **密钥安全**：Web 控制台默认使用随机密钥，公网环境务必通过 `clashctl web secret --set` 修改并定期更换。

## 致谢

感谢 [nelvko/clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install/tree/master) 原项目的贡献。