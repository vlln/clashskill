#!/usr/bin/env bash

THIS_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE:-${(%):-%N}}")")
. "$THIS_SCRIPT_DIR/common.sh"

_set_system_proxy() {
    local mixed_port=$("$BIN_YQ" '.mixed-port // ""' "$CLASH_CONFIG_RUNTIME")
    local http_port=$("$BIN_YQ" '.port // ""' "$CLASH_CONFIG_RUNTIME")
    local socks_port=$("$BIN_YQ" '.socks-port // ""' "$CLASH_CONFIG_RUNTIME")

    local auth=$("$BIN_YQ" '.authentication[0] // ""' "$CLASH_CONFIG_RUNTIME")
    [ -n "$auth" ] && auth=$auth@

    local bind_addr=$(_get_bind_addr)
    local http_proxy_addr="http://${auth}${bind_addr}:${http_port:-${mixed_port}}"
    local socks_proxy_addr="socks5h://${auth}${bind_addr}:${socks_port:-${mixed_port}}"
    local no_proxy_addr="localhost,127.0.0.1,::1"

    # 设置当前 shell 环境变量
    export http_proxy=$http_proxy_addr
    export HTTP_PROXY=$http_proxy
    export https_proxy=$http_proxy
    export HTTPS_PROXY=$https_proxy
    export all_proxy=$socks_proxy_addr
    export ALL_PROXY=$all_proxy
    export no_proxy=$no_proxy_addr
    export NO_PROXY=$no_proxy

    # 写入全局配置文件（新终端自动生效）
    local proxy_env_file="${CLASH_BASE_DIR}/.proxy.env"
    mkdir -p "$(dirname "$proxy_env_file")"
    cat > "$proxy_env_file" <<EOF
export http_proxy=$http_proxy_addr
export HTTP_PROXY=$http_proxy_addr
export https_proxy=$http_proxy_addr
export HTTPS_PROXY=$http_proxy_addr
export all_proxy=$socks_proxy_addr
export ALL_PROXY=$socks_proxy_addr
export no_proxy=$no_proxy_addr
export NO_PROXY=$no_proxy_addr
EOF
}
_unset_system_proxy() {
    # 清除当前 shell 环境变量
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset all_proxy
    unset ALL_PROXY
    unset no_proxy
    unset NO_PROXY

    # 清除全局配置文件
    local proxy_env_file="${CLASH_BASE_DIR}/.proxy.env"
    [ -f "$proxy_env_file" ] && rm -f "$proxy_env_file"
}
_detect_proxy_port() {
    local mixed_port=$("$BIN_YQ" '.mixed-port // ""' "$CLASH_CONFIG_RUNTIME")
    local http_port=$("$BIN_YQ" '.port // ""' "$CLASH_CONFIG_RUNTIME")
    local socks_port=$("$BIN_YQ" '.socks-port // ""' "$CLASH_CONFIG_RUNTIME")
    [ -z "$mixed_port" ] && [ -z "$http_port" ] && [ -z "$socks_port" ] && mixed_port=7890

    local newPort count=0
    local port_list=(
        "mixed_port|mixed-port"
        "http_port|port"
        "socks_port|socks-port"
    )
    _clashstatus >&/dev/null && local isActive='true'
    for entry in "${port_list[@]}"; do
        local var_name="${entry%|*}"
        local yaml_key="${entry#*|}"

        eval "local var_val=\${$var_name}"

        [ -n "$var_val" ] && _is_port_used "$var_val" && [ "$isActive" != "true" ] && {
            newPort=$(_get_random_port)
            ((count++))
            _failcat '🎯' "端口冲突：[$yaml_key] $var_val 🎲 随机分配 $newPort"
            "$BIN_YQ" -i ".${yaml_key} = $newPort" "$CLASH_CONFIG_MIXIN"
        }
    done
    ((count)) && _merge_config
}

_clashon() {
    _detect_proxy_port
    _clashstatus >&/dev/null || placeholder_start
    _clashstatus >&/dev/null || {
        _failcat '启动失败: 执行 clashctl log 查看日志'
        return 1
    }
    _clashproxy >/dev/null && _set_system_proxy
    _okcat '已开启代理环境'
}

watch_proxy() {
    [ -z "$http_proxy" ] && {
        # [[ "$0" == -* ]] && { # 登录式shell
        [[ $- == *i* ]] && { # 交互式shell
            placeholder_watch_proxy
        }
    }
}

_clashoff() {
    _clashstatus >&/dev/null && {
        placeholder_stop >/dev/null
        _clashstatus >&/dev/null && _tunstatus >&/dev/null && {
            _tunoff || _error_quit "请先关闭 Tun 模式"
        }
        placeholder_stop >/dev/null
        _clashstatus >&/dev/null && {
            _failcat '代理环境关闭失败'
            return 1
        }
    }
    _unset_system_proxy
    _okcat '已关闭代理环境'
}

_clashrestart() {
    _clashoff >/dev/null
    _clashon
}

# ========== proxy 命令 - 代理控制 ==========
_clashproxy() {
    case "$1" in
    on)
        _detect_proxy_port
        _clashstatus >&/dev/null || placeholder_start
        _clashstatus >&/dev/null || {
            _failcat '启动失败: 执行 clashctl proxy log 查看日志'
            return 1
        }
        _clashproxy_sys on >/dev/null
        _okcat '已开启代理'
        ;;
    off)
        _clashstatus >&/dev/null && {
            placeholder_stop >/dev/null
            _clashstatus >&/dev/null && _tunstatus >&/dev/null && {
                _tunoff || _error_quit "请先关闭 Tun 模式"
            }
            placeholder_stop >/dev/null
            _clashstatus >&/dev/null && {
                _failcat '关闭失败'
                return 1
            }
        }
        _clashproxy_sys off >/dev/null
        _unset_system_proxy
        _okcat '已关闭代理'
        ;;
    status)
        placeholder_status "$@"
        placeholder_is_active >&/dev/null
        ;;
    mode)
        shift
        _clashproxy_mode "$@"
        ;;
    log)
        placeholder_log "$@"
        ;;
    restart)
        _clashproxy off >/dev/null
        _clashproxy on
        ;;
    sys)
        shift
        _clashproxy_sys "$@"
        ;;
    -h|--help|*)
        cat <<'EOF'

代理控制

用法:
  clashctl proxy on                   # 开含代理
  clashctl proxy off                  # 关闭代理
  clashctl proxy status               # 查看状态
  clashctl proxy mode <mode>          # 切换模式
  clashctl proxy log                  # 查看日志
  clashctl proxy restart              # 重启代理
  clashctl proxy sys [on|off]         # 系统代理开关

模式:
  rule          规则模式
  global        全局模式
  direct        直连模式

示例:
  clashctl proxy on
  clashctl proxy mode global
  clashctl proxy sys on

EOF
        ;;
    esac
}

# 切换代理模式
_clashproxy_mode() {
    _detect_ext_addr
    case "$1" in
    rule|global|direct)
        _clashstatus >&/dev/null || {
            _failcat "$KERNEL_NAME 未运行，请先执行 clashctl proxy on"
            return 1
        }
        local mode="$1"
        local secret=$(_get_secret)
        local res=$(curl -s --noproxy "*" -X PATCH -H "Authorization: Bearer ${secret}" -H "Content-Type: application/json" "http://${EXT_IP}:${EXT_PORT}/configs" -d "{\"mode\":\"${mode}\"}" 2>/dev/null)
        if [[ -z "$res" ]]; then
            _okcat "已切换到 ${mode} 模式"
        else
            _failcat "模式切换失败: $res"
            return 1
        fi
        ;;
    *)
        cat <<'EOF'

切换代理模式

用法:
  clashctl proxy mode rule      # 规则模式
  clashctl proxy mode global    # 全局模式
  clashctl proxy mode direct    # 直连模式

EOF
        ;;
    esac
}

# 系统代理控制
_clashproxy_sys() {
    case "$1" in
    on)
        _clashstatus >&/dev/null || {
            _failcat "$KERNEL_NAME 未运行，请先执行 clashctl proxy on"
            return 1
        }
        "$BIN_YQ" -i '._custom.system-proxy.enable = true' "$CLASH_CONFIG_MIXIN"
        _set_system_proxy
        _okcat '已开启系统代理'
        ;;
    off)
        "$BIN_YQ" -i '._custom.system-proxy.enable = false' "$CLASH_CONFIG_MIXIN"
        _unset_system_proxy
        _okcat '已关闭系统代理'
        ;;
    *)
        local system_proxy_enable=$("$BIN_YQ" '._custom.system-proxy.enable' "$CLASH_CONFIG_MIXIN" 2>/dev/null)
        case $system_proxy_enable in
        true)
            _okcat "系统代理：开启
$(env | grep -i 'proxy=')"
            ;;
        *)
            _failcat "系统代理：关闭"
            ;;
        esac
        ;;
    esac
}

_clashstatus() {
    placeholder_status "$@"
    placeholder_is_active >&/dev/null
}

_clashlog() {
    placeholder_log "$@"
}


_merge_config() {
    cat "$CLASH_CONFIG_RUNTIME" >"$CLASH_CONFIG_TEMP" 2>/dev/null
    # shellcheck disable=SC2016
    "$BIN_YQ" eval-all '
      ########################################
      #              Load Files              #
      ########################################
      select(fileIndex==0) as $config |
      select(fileIndex==1) as $mixin |
      
      ########################################
      #              Deep Merge              #
      ########################################
      $mixin |= del(._custom) |
      (($config // {}) * $mixin) as $runtime |
      $runtime |
      
      ########################################
      #               Rules                  #
      ########################################
      .rules = (
        ($mixin.rules.prefix // []) +
        ($config.rules // []) +
        ($mixin.rules.suffix // [])
      ) |
      
      ########################################
      #                Proxies               #
      ########################################
      .proxies = (
        ($mixin.proxies.prefix // []) +
        (
          ($config.proxies // []) as $configList |
          ($mixin.proxies.override // []) as $overrideList |
          $configList | map(
            . as $configItem |
            (
              $overrideList[] | select(.name == $configItem.name)
            ) // $configItem
          )
        ) +
        ($mixin.proxies.suffix // [])
      ) |
      
      ########################################
      #             ProxyGroups              #
      ########################################
      .proxy-groups = (
        ($mixin.proxy-groups.prefix // []) +
        (
          ($config.proxy-groups // []) as $configList |
          ($mixin.proxy-groups.override // []) as $overrideList |
          $configList | map(
            . as $configItem |
            (
              $overrideList[] | select(.name == $configItem.name)
            ) // $configItem
          )
        ) +
        ($mixin.proxy-groups.suffix // [])
      )
    ' "$CLASH_CONFIG_BASE" "$CLASH_CONFIG_MIXIN" >"$CLASH_CONFIG_RUNTIME"
    _valid_config "$CLASH_CONFIG_RUNTIME" || {
        cat "$CLASH_CONFIG_TEMP" >"$CLASH_CONFIG_RUNTIME"
        _error_quit "验证失败：请检查 Mixin 配置"
    }
}

_merge_config_restart() {
    _merge_config
    placeholder_stop >/dev/null
    _clashstatus >&/dev/null && _tunstatus >&/dev/null && {
        _tunoff || _error_quit "请先关闭 Tun 模式"
    }
    placeholder_stop >/dev/null
    sleep 0.1
    placeholder_start >/dev/null
    sleep 0.1
}
_get_secret() {
    "$BIN_YQ" '.secret // ""' "$CLASH_CONFIG_RUNTIME"
}
_clashweb() {
    case "$1" in
    -h|--help)
        cat <<EOF

web - Web 控制台和密钥管理

查看控制台:
  clashctl web                    # 显示 Web 控制台地址

密钥管理:
  clashctl web secret             # 查看当前密钥
  clashctl web secret --set <key> # 设置新密钥

EOF
        return 0
        ;;
    secret)
        shift
        _clashweb_secret "$@"
        ;;
    *)
        _clashweb_info
        ;;
    esac
}

_clashweb_info() {
    _detect_ext_addr
    _clashstatus >&/dev/null || _clashon >/dev/null
    local query_url='api64.ipify.org'
    local public_ip=$(curl -s --noproxy "*" --location --max-time 2 $query_url)
    local public_address="http://${public_ip:-公网}:${EXT_PORT}/ui"

    local local_ip=$EXT_IP
    local local_address="http://${local_ip}:${EXT_PORT}/ui"
    printf "\n"
    printf "╔═══════════════════════════════════════════════╗\n"
    printf "║                %s                  ║\n" "$(_okcat 'Web 控制台')"
    printf "║═══════════════════════════════════════════════║\n"
    printf "║                                               ║\n"
    printf "║     🔓 注意放行端口：%-5s                    ║\n" "$EXT_PORT"
    printf "║     🏠 内网：%-31s  ║\n" "$local_address"
    printf "║     🌏 公网：%-31s  ║\n" "$public_address"
    printf "║     ☁️  公共：%-31s  ║\n" "$URL_CLASH_UI"
    printf "║                                               ║\n"
    printf "╚═══════════════════════════════════════════════╝\n"
    printf "\n"
}

_clashweb_secret() {
    case "$1" in
    -h|--help)
        cat <<EOF

- 查看 Web 密钥
  clashctl web secret

- 设置 Web 密钥
  clashctl web secret --set <new_secret>

EOF
        return 0
        ;;
    --set)
        shift
        _clashweb_secret_set "$@"
        ;;
    *)
        _clashweb_secret_show
        ;;
    esac
}

_clashweb_secret_show() {
    _okcat "当前密钥：$(_get_secret)"
}

_clashweb_secret_set() {
    if [ $# -ne 1 ]; then
        _failcat "用法: clashctl web secret --set <new_secret>"
        return 1
    fi
    "$BIN_YQ" -i ".secret = \"$1\"" "$CLASH_CONFIG_MIXIN" || {
        _failcat "密钥更新失败，请重新输入"
        return 1
    }
    _merge_config_restart
    _okcat "密钥更新成功，已重启生效"
}


_tunstatus() {
    local tun_status=$("$BIN_YQ" '.tun.enable' "${CLASH_CONFIG_RUNTIME}")
    case $tun_status in
    true)
        _okcat 'Tun 状态：启用'
        ;;
    *)
        _failcat 'Tun 状态：关闭'
        ;;
    esac
}
_tunoff() {
    _tunstatus >/dev/null || return 0
    sudo placeholder_stop
    _clashstatus >&/dev/null || {
        "$BIN_YQ" -i '.tun.enable = false' "$CLASH_CONFIG_MIXIN"
        _merge_config
        _clashon >/dev/null
        _okcat "Tun 模式已关闭"
        return 0
    }
    _tunstatus >&/dev/null && _failcat "Tun 模式关闭失败"
}
_sudo_restart() {
    sudo placeholder_stop
    placeholder_sudo_start
    sleep 0.5
}
_tunon() {
    _tunstatus 2>/dev/null && return 0
    sudo placeholder_stop
    "$BIN_YQ" -i '.tun.enable = true' "$CLASH_CONFIG_MIXIN"
    _merge_config
    placeholder_sudo_start
    sleep 0.5
    _clashstatus >&/dev/null || _error_quit "Tun 模式开启失败"
    local fail_msg="Start TUN listening error|unsupported kernel version"
    local ok_msg="Tun adapter listening at|TUN listening iface"
    _clashlog | grep -E -m1 -qs "$fail_msg" && {
        [ "$KERNEL_NAME" = 'mihomo' ] && {
            "$BIN_YQ" -i '.tun.auto-redirect = false' "$CLASH_CONFIG_MIXIN"
            _merge_config
            _sudo_restart
        }
        _clashlog | grep -E -m1 -qs "$ok_msg" || {
            _clashlog | grep -E -m1 "$fail_msg"
            _tunoff >&/dev/null
            _error_quit '系统内核版本不支持 Tun 模式'
        }
    }
    _okcat "Tun 模式已开启"
}

_clashtun() {
    case "$1" in
    -h | --help)
        cat <<EOF

- 查看 Tun 状态
  clashctl tun

- 开启 Tun 模式
  clashctl tun on

- 关闭 Tun 模式
  clashctl tun off
  
EOF
        return 0
        ;;
    on)
        _tunon
        ;;
    off)
        _tunoff
        ;;
    *)
        _tunstatus
    esac
}


_clashupgrade() {
    for arg in "$@"; do
        case $arg in
        -h | --help)
            cat <<EOF
Usage:
  clashctl upgrade [OPTIONS]

Options:
  -v, --verbose       输出内核升级日志
  -r, --release       升级至稳定版
  -a, --alpha         升级至测试版
  -h, --help          显示帮助信息

EOF
            return 0
            ;;
        -v | --verbose)
            local log_flag=true
            ;;
        -r | --release)
            channel="release"
            ;;
        -a | --alpha)
            channel="alpha"
            ;;
        *)
            channel=""
            ;;
        esac
    done

    _detect_ext_addr
    _clashstatus >&/dev/null || _clashon >/dev/null
    _okcat '⏳' "请求内核升级..."
    [ "$log_flag" = true ] && {
        log_cmd=(placeholder_follow_log)
        ("${log_cmd[@]}" &)

    }
    local res=$(
        curl -X POST \
            --silent \
            --noproxy "*" \
            --location \
            -H "Authorization: Bearer $(_get_secret)" \
            "http://${EXT_IP}:${EXT_PORT}/upgrade?channel=$channel"
    )
    [ "$log_flag" = true ] && pkill -9 -f "${log_cmd[*]}"

    grep '"status":"ok"' <<<"$res" && {
        _okcat "内核升级成功"
        return 0
    }
    grep 'already using latest version' <<<"$res" && {
        _okcat "已是最新版本"
        return 0
    }
    _failcat "内核升级失败，请检查网络或稍后重试"
}

_clashsub() {
    case "$1" in
    add)
        shift
        _sub_add "$@"
        ;;
    del)
        shift
        _sub_del "$@"
        ;;
    list | ls | '')
        shift
        _sub_list "$@"
        ;;
    use)
        shift
        _sub_use "$@"
        ;;
    update)
        shift
        _sub_update "$@"
        ;;
    log)
        shift
        _sub_log "$@"
        ;;
    merge)
        shift
        _clashmerge "$@"
        ;;
    -h | --help | *)
        cat <<'EOF'
clashctl sub - Clash 订阅管理工具

用法: 
  clashctl sub COMMAND [OPTIONS]

命令:
  add <url>       添加订阅
  ls              查看订阅
  del <id>        删除订阅
  use <id>        使用订阅
  update [id]     更新订阅
  log             订阅日志
  merge <ids...>  融合多个订阅

示例:
  clashctl sub merge 1 2 3 -o "融合订阅"

EOF
        ;;
    esac
}
_sub_add() {
    local url=$1
    [ -z "$url" ] && {
        echo -n "$(_okcat '✈️ ' '请输入要添加的订阅链接：')"
        read -r url
        [ -z "$url" ] && _error_quit "订阅链接不能为空"
    }
    _get_url_by_id "$id" >/dev/null && _error_quit "该订阅链接已存在"

    _download_config "$CLASH_CONFIG_TEMP" "$url"
    _valid_config "$CLASH_CONFIG_TEMP" || _error_quit "订阅无效，请检查：
    原始订阅：${CLASH_CONFIG_TEMP}.raw
    转换订阅：$CLASH_CONFIG_TEMP
    转换日志：$BIN_SUBCONVERTER_LOG"

    local id=$("$BIN_YQ" '.profiles // [] | (map(.id) | max) // 0 | . + 1' "$CLASH_PROFILES_META")
    local profile_path="${CLASH_PROFILES_DIR}/${id}.yaml"
    mv "$CLASH_CONFIG_TEMP" "$profile_path"

    "$BIN_YQ" -i "
         .profiles = (.profiles // []) + 
         [{
           \"id\": $id,
           \"path\": \"$profile_path\",
           \"url\": \"$url\"
         }]
    " "$CLASH_PROFILES_META"
    _logging_sub "➕ 已添加订阅：[$id] $url"
    _okcat '🎉' "订阅已添加：[$id] $url"
}
_sub_del() {
    local id=$1
    [ -z "$id" ] && {
        echo -n "$(_okcat '✈️ ' '请输入要删除的订阅 id：')"
        read -r id
        [ -z "$id" ] && _error_quit "订阅 id 不能为空"
    }
    local profile_path url
    profile_path=$(_get_path_by_id "$id") || _error_quit "订阅 id 不存在，请检查"
    url=$(_get_url_by_id "$id")
    use=$("$BIN_YQ" '.use // ""' "$CLASH_PROFILES_META")
    [ "$use" = "$id" ] && _error_quit "删除失败：订阅 $id 正在使用中，请先切换订阅"
    /usr/bin/rm -f "$profile_path"
    "$BIN_YQ" -i "del(.profiles[] | select(.id == \"$id\"))" "$CLASH_PROFILES_META"
    _logging_sub "➖ 已删除订阅：[$id] $url"
    _okcat '🎉' "订阅已删除：[$id] $url"
}
_sub_list() {
    "$BIN_YQ" "$CLASH_PROFILES_META"
}
_sub_use() {
    "$BIN_YQ" -e '.profiles // [] | length == 0' "$CLASH_PROFILES_META" >&/dev/null &&
        _error_quit "当前无可用订阅，请先添加订阅"
    local id=$1
    [ -z "$id" ] && {
        clashctl sub ls
        echo -n "$(_okcat '✈️ ' '请输入要使用的订阅 id：')"
        read -r id
        [ -z "$id" ] && _error_quit "订阅 id 不能为空"
    }
    local profile_path url
    profile_path=$(_get_path_by_id "$id") || _error_quit "订阅 id 不存在，请检查"
    url=$(_get_url_by_id "$id")
    
    cat "$profile_path" > "$CLASH_CONFIG_BASE"
    _merge_config_restart
    "$BIN_YQ" -i ".use = $id" "$CLASH_PROFILES_META"
    _logging_sub "🔥 订阅已切换为：[$id] $url"
    _okcat '🔥' '订阅已生效'
}
_get_path_by_id() {
    "$BIN_YQ" -e ".profiles[] | select(.id == \"$1\") | .path" "$CLASH_PROFILES_META" 2>/dev/null
}
_get_url_by_id() {
    "$BIN_YQ" -e ".profiles[] | select(.id == \"$1\") | .url" "$CLASH_PROFILES_META" 2>/dev/null
}
_sub_update() {
    local arg is_convert
    for arg in "$@"; do
        case $arg in
        --auto)
            command -v crontab >/dev/null || _error_quit "未检测到 crontab 命令，请先安装 cron 服务"
            crontab -l | grep -qs 'clashctl sub update' || {
                (
                    crontab -l 2>/dev/null
                    echo "0 0 */2 * * $SHELL -i -c 'clashctl sub update'"
                ) | crontab -
            }
            _okcat "已设置定时更新订阅"
            return 0
            ;;
        --convert)
            is_convert=true
            shift
            ;;
        esac
    done
    local id=$1
    [ -z "$id" ] && id=$("$BIN_YQ" '.use // 1' "$CLASH_PROFILES_META")
    local url profile_path
    url=$(_get_url_by_id "$id") || _error_quit "订阅 id 不存在，请检查"
    profile_path=$(_get_path_by_id "$id")
    _okcat "✈️ " "更新订阅：[$id] $url"

    [ "$is_convert" = true ] && {
        _download_convert_config "$CLASH_CONFIG_TEMP" "$url"
    }
    [ "$is_convert" != true ] && {
        _download_config "$CLASH_CONFIG_TEMP" "$url"
    }
    _valid_config "$CLASH_CONFIG_TEMP" || {
        _logging_sub "❌ 订阅更新失败：[$id] $url"
        _error_quit "订阅无效：请检查：
    原始订阅：${CLASH_CONFIG_TEMP}.raw
    转换订阅：$CLASH_CONFIG_TEMP
    转换日志：$BIN_SUBCONVERTER_LOG"
    }
    _logging_sub "✅ 订阅更新成功：[$id] $url"
    cat "$CLASH_CONFIG_TEMP" >"$profile_path"
    use=$("$BIN_YQ" '.use // ""' "$CLASH_PROFILES_META")
    [ "$use" = "$id" ] && _clashsub use "$use" && return
    _okcat '订阅已更新'
}
_logging_sub() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >>"${CLASH_PROFILES_LOG}"
}
_sub_log() {
    tail <"${CLASH_PROFILES_LOG}" "$@"
}

_clashrules() {
    case "$1" in
    -h|--help)
        cat <<EOF

rules - 全局规则配置管理

查看配置路径（Agent友好）:
  clashctl rules --path           # 运行时配置路径
  clashctl rules --global --path  # 全局配置路径
  clashctl rules --base --path    # 原始订阅配置路径

查看配置内容:
  clashctl rules                  # 查看运行时配置
  clashctl rules --global         # 查看全局配置
  clashctl rules --base           # 查看原始订阅配置

编辑配置:
  clashctl rules edit             # 编辑全局配置（默认编辑器）

直接修改（Agent友好）:
  clashctl rules set <yaml>       # 直接设置全局配置（YAML字符串）
  clashctl rules set -f <file>    # 从文件设置全局配置

启用/禁用自动应用:
  clashctl rules on               # 启用（新订阅自动应用）
  clashctl rules off              # 禁用（新订阅不自动应用）
  clashctl rules status           # 查看状态

EOF
        return 0
        ;;
    edit)
        _clashrules_edit
        ;;
    set)
        shift
        _clashrules_set "$@"
        ;;
    on|enable)
        _clashrules_on
        ;;
    off|disable)
        _clashrules_off
        ;;
    status)
        _clashrules_status
        ;;
    --path)
        echo "$CLASH_CONFIG_RUNTIME"
        ;;
    --global)
        shift
        _clashrules_global "$@"
        ;;
    --base)
        shift
        _clashrules_base "$@"
        ;;
    *)
        _clashrules_runtime "$@"
        ;;
    esac
}

_clashrules_runtime() {
    case "$1" in
    --path)
        echo "$CLASH_CONFIG_RUNTIME"
        ;;
    *)
        less "$CLASH_CONFIG_RUNTIME"
        ;;
    esac
}

_clashrules_global() {
    case "$1" in
    --path)
        echo "$CLASH_CONFIG_MIXIN"
        ;;
    *)
        less "$CLASH_CONFIG_MIXIN"
        ;;
    esac
}

_clashrules_base() {
    case "$1" in
    --path)
        echo "$CLASH_CONFIG_BASE"
        ;;
    *)
        less "$CLASH_CONFIG_BASE"
        ;;
    esac
}

_clashrules_edit() {
    ${EDITOR:-vim} "$CLASH_CONFIG_MIXIN" && {
        _merge_config_restart && _okcat "全局配置已保存并生效"
    }
}

_clashrules_set() {
    local from_file=false
    local content=""
    
    # 解析参数
    while (($#)); do
        case "$1" in
        -f|--file)
            from_file=true
            shift
            ;;
        *)
            content="$1"
            shift
            ;;
        esac
    done
    
    if [ "$from_file" = true ]; then
        # 从文件读取
        if [ -f "$content" ]; then
            cp "$content" "$CLASH_CONFIG_MIXIN" || {
                _failcat "复制文件失败"
                return 1
            }
        else
            _failcat "文件不存在: $content"
            return 1
        fi
    else
        # 直接写入 YAML 内容
        echo "$content" > "$CLASH_CONFIG_MIXIN" || {
            _failcat "写入配置失败"
            return 1
        }
    fi
    
    # 验证 YAML 格式
    if ! "$BIN_YQ" '.' "$CLASH_CONFIG_MIXIN" > /dev/null 2>&1; then
        _failcat "YAML 格式无效，配置未应用"
        return 1
    fi
    
    _merge_config_restart
    _okcat "全局配置已更新并生效"
}

_clashrules_on() {
    rm -f "${CLASH_CONFIG_MIXIN}.disabled"
    _okcat "全局配置自动应用已启用"
}

_clashrules_off() {
    touch "${CLASH_CONFIG_MIXIN}.disabled"
    _okcat "全局配置自动应用已禁用"
}

_clashrules_status() {
    if [ -f "$CLASH_CONFIG_MIXIN" ]; then
        local status="启用"
        [ -f "${CLASH_CONFIG_MIXIN}.disabled" ] && status="禁用"
        _okcat "全局配置: $status"
        echo "路径: $CLASH_CONFIG_MIXIN"
    else
        _failcat "全局配置未创建"
    fi
}

function clashctl() {
    case "$1" in
    proxy)
        shift
        _clashproxy "$@"
        ;;
    node)
        shift
        _clashnode "$@"
        ;;
    net)
        shift
        _clashnet "$@"
        ;;
    test)
        shift
        _clashtest "$@"
        ;;
    sub)
        shift
        _clashsub "$@"
        ;;
    rules)
        shift
        _clashrules "$@"
        ;;
    tun)
        shift
        _clashtun "$@"
        ;;
    sys)
        shift
        _clashsys "$@"
        ;;
    web|ui)
        shift
        _clashweb "$@"
        ;;
    *)
        _clashhelp
        ;;
    esac
}

_clashhelp() {
    cat <<'EOF'

用法: clashctl <命令> [子命令] [options]

命令树:
clashctl
├── proxy        代理核心(on/off/status/mode)
├── node         节点管理(ls/use/test)
├── net          网络诊断(ping/dns/traffic/conn)
├── test         网络测试(network/dns/delay/nodes)
├── sub          订阅管理(add/ls/use/update/merge/del)
├── rules        规则配置(edit/set/path/on/off)
├── tun          Tun 模式(on/off/status)
├── web          Web 控制台和密钥管理
└── sys          系统维护(upgrade/log)

快速开始:
  clashctl proxy on                       # 开启代理
  clashctl proxy mode global              # 全局模式
  clashctl node ls                        # 列出节点
  clashctl node use #1 @3                 # 切换节点
  clashctl node test #1 --all             # 测试所有节点
  clashctl net traffic                    # 流量统计

配置路径（Agent友好）:
  clashctl rules --path                   # 运行时配置路径
  clashctl rules --global --path          # 全局配置路径
  clashctl rules --base --path            # 原始订阅配置路径

完整文档: https://github.com/nelvko/clash-for-linux-install

Global Options:
  -h, --help            显示帮助信息
  --json                JSON格式输出

For more help on how to use clashctl, head to https://github.com/nelvko/clash-for-linux-install
EOF
}


# ========== select 命令 - 节点选择 ==========
_clashnode() {
    _clashstatus >&/dev/null || {
        _failcat "$KERNEL_NAME 未运行，请先执行 clashctl proxy on"
        return 1
    }
    _detect_ext_addr
    local secret=$(_get_secret)
    local api_base="http://${EXT_IP}:${EXT_PORT}"
    local cache_dir="${CLASH_RESOURCES_DIR}/.cache"
    local selector_cache="${cache_dir}/selectors"
    local node_cache="${cache_dir}/nodes"
    
    mkdir -p "$cache_dir"
    
    _get_selector_by_id() {
        local input="$1"
        if [[ "$input" == \#* ]]; then
            local id="${input#\#}"
            if [[ "$id" =~ ^[0-9]+$ ]] && [ -f "$selector_cache" ]; then
                awk -F'\t' -v n="$id" '$1 == n {print $2; exit}' "$selector_cache" 2>/dev/null
                return
            fi
        fi
        echo "$input"
    }
    
    _get_node_by_id() {
        local input="$1"
        if [[ "$input" == @* ]]; then
            local id="${input#@}"
            if [[ "$id" =~ ^[0-9]+$ ]] && [ -f "$node_cache" ]; then
                awk -F'\t' -v n="$id" '$1 == n {print $2; exit}' "$node_cache" 2>/dev/null
                return
            fi
        fi
        echo "$input"
    }
    
    case "$1" in
    list|ls)
        local data=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies" 2>/dev/null)
        local selectors=$(echo "$data" | "$BIN_YQ" -o=tsv '.proxies | to_entries | .[] | select(.value.type == "Selector") | [.key, .value.type, .value.now // "-"] | @tsv')
        local all_nodes=$(echo "$data" | "$BIN_YQ" -o=tsv '.proxies | to_entries | .[] | select(.value.type != "Selector") | [.key, .value.type] | @tsv')
        
        echo ""
        echo "========== 策略组 (Selector) 用 #n =========="
        local idx=1
        echo "$selectors" | while IFS=$'\t' read -r name type now; do
            printf "#%-2d %-30s → %s\n" "$idx" "$name" "$now"
            printf "%s\t%s\n" "$idx" "$name" >> "$selector_cache.tmp"
            ((idx++))
        done
        
        echo ""
        echo "========== 节点 (Node) 用 @n =========="
        local idx=1
        echo "$all_nodes" | while IFS=$'\t' read -r name type; do
            printf "@%-2d %-30s (%s)\n" "$idx" "$name" "$type"
            printf "%s\t%s\n" "$idx" "$name" >> "$node_cache.tmp"
            ((idx++))
        done
        
        mv -f "$selector_cache.tmp" "$selector_cache" 2>/dev/null
        mv -f "$node_cache.tmp" "$node_cache" 2>/dev/null
        
        echo ""
        echo "用法: clashctl node use #1 @3"
        ;;
    use)
        local selector_input="${2:-}"
        local node_input="${3:-}"
        
        [ -z "$selector_input" ] && { _failcat "请指定策略组: clashctl node use <#策略组> <@节点>"; return 1; }
        [ -z "$node_input" ] && { _failcat "请指定节点"; return 1; }
        
        local selector=$(_get_selector_by_id "$selector_input")
        [ -z "$selector" ] && { _failcat "无效的策略组: $selector_input"; return 1; }
        
        local node=$(_get_node_by_id "$node_input")
        [ -z "$node" ] && { _failcat "无效的节点: $node_input"; return 1; }
        
        local encoded_name=$(printf '%s' "$selector" | sed 's/ /%20/g')
        local res=$(curl -s --noproxy "*" -X PUT -H "Authorization: Bearer ${secret}" -H "Content-Type: application/json" "${api_base}/proxies/${encoded_name}" -d "{\"name\":\"${node}\"}" 2>/dev/null)
        [ -z "$res" ] && _okcat "已切换: [$selector] → ${node}" || _failcat "切换失败: $res"
        ;;
    test)
        shift
        _clashnode_test "$@"
        ;;
    *)
        cat <<'EOF'

node - 节点相关操作

用法:
  clashctl node ls                  # 列出策略组(#n)和节点(@n)
  clashctl node use #n @m           # 切换节点
  clashctl node test #n [opts]      # 测试节点延迟
  clashctl node test #1 --sort      # 测试并按延迟排序

选项:
  --all, -a        测试所有节点
  --sort, -s       按延迟排序
  --url, -u        自定义测试URL
  --timeout, -t    超时时间(ms)

示例:
  clashctl node use #1 @3           # 切换到节点@3
  clashctl node test #1 --all       # 测试策略组#1下所有节点
  clashctl node test #1 -a -s       # 测试并排序

EOF
        ;;
    esac
}

# ========== test 命令 - 网络测试 ==========
_clashtest() {
    case "$1" in
    network)
        shift
        _clashtest_network "$@"
        ;;
    dns)
        shift
        _clashtest_dns "$@"
        ;;
    delay)
        shift
        _clashtest_delay "$@"
        ;;
    nodes)
        shift
        _clashtest_nodes "$@"
        ;;
    -h|--help)
        cat <<'EOF'

网络测试

用法:
  clashctl test network           # 完整网络诊断（直连+代理）
  clashctl test network --proxy   # 只测试代理连通
  clashctl test network --direct  # 只测试直连连通
  clashctl test dns [domain]      # DNS解析测试
  clashctl test delay #n          # 测试策略组节点延迟
  clashctl test delay #n --all    # 测试策略组下所有节点
  clashctl test nodes             # 测试所有节点并排序

示例:
  clashctl test                   # 等同于 test network
  clashctl test dns www.baidu.com
  clashctl test delay #1 --all --sort
  clashctl test nodes

EOF
        ;;
    *)
        _clashtest network
        ;;
    esac
}

# 网络连通测试
_clashtest_network() {
    local mixed_port=$("$BIN_YQ" '.mixed-port // 7890' "$CLASH_CONFIG_RUNTIME")
    local proxy_url="http://127.0.0.1:${mixed_port}"
    local test_mode="${1:-all}"
    
    case "$test_mode" in
    --proxy)
        echo "=== 测试代理连通性 ==="
        curl -s --proxy "$proxy_url" --max-time 5 \
            http://ip-api.com/json 2>/dev/null | \
            "$BIN_YQ" -P '{ip: .query, country: .country, isp: .isp, proxy: true}' || \
            _failcat "代理测试失败"
        ;;
    --direct)
        echo "=== 测试直连连通性 ==="
        curl -s --max-time 5 \
            http://ip-api.com/json 2>/dev/null | \
            "$BIN_YQ" -P '{ip: .query, country: .country, isp: .isp, proxy: false}' || \
            _failcat "直连测试失败"
        ;;
    all|*)
        echo "========== 网络诊断测试 =========="
        echo ""
        _clashtest_network --direct
        echo ""
        _clashstatus >&/dev/null && {
            _clashtest_network --proxy
        } || {
            echo "=== 代理状态 ==="
            _failcat "代理未运行"
        }
        echo ""
        echo "=================================="
        ;;
    esac
}

# DNS 测试
_clashtest_dns() {
    local domain="${1:-www.google.com}"
    echo "=== DNS 解析测试: $domain ==="
    dig @127.0.0.1 -p 1053 "$domain" +short 2>/dev/null || \
        nslookup "$domain" 127.0.0.1 2>/dev/null || \
        _failcat "DNS 解析失败"
}

# 节点延迟测试
_clashtest_delay() {
    _clashstatus >&/dev/null || {
        _failcat "$KERNEL_NAME 未运行"
        return 1
    }
    _detect_ext_addr
    
    local selector_input="${1:-}"
    [ -z "$selector_input" ] && { _failcat "请指定策略组: clashctl test delay <#策略组> [options]"; return 1; }
    shift
    
    local cache_dir="${CLASH_RESOURCES_DIR}/.cache"
    local selector_cache="${cache_dir}/selectors"
    local selector=$(echo "$selector_input" | sed 's/^#//')
    if [[ "$selector" =~ ^[0-9]+$ ]] && [ -f "$selector_cache" ]; then
        selector=$(awk -F'\t' -v n="$selector" '$1 == n {print $2; exit}' "$selector_cache" 2>/dev/null)
    fi
    [ -z "$selector" ] && { _failcat "无效的策略组: $selector_input"; return 1; }
    
    local test_url="${TEST_URL:-http://www.gstatic.com/generate_204}"
    local test_timeout="${TEST_TIMEOUT:-5000}"
    local test_all=false
    local sort_by_delay=false
    
    while (($#)); do
        case "$1" in
            --url|-u) test_url="$2"; shift 2 ;;
            --timeout|-t) test_timeout="$2"; shift 2 ;;
            --all|-a) test_all=true; shift ;;
            --sort|-s) sort_by_delay=true; shift ;;
            *) shift ;;
        esac
    done
    
    local secret=$(_get_secret)
    local api_base="http://${EXT_IP}:${EXT_PORT}"
    local encoded_name=$(printf '%s' "$selector" | sed 's/ /%20/g')
    
    if [ "$test_all" = true ]; then
        echo "测试策略组: $selector (所有节点)"
        echo "URL: $test_url, 超时: ${test_timeout}ms"
        echo ""
        
        local all_nodes=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies/${encoded_name}" 2>/dev/null | "$BIN_YQ" '.all // [] | .[]')
        [ -z "$all_nodes" ] && { _failcat "获取节点列表失败"; return 1; }
        
        local result_file=$(mktemp)
        echo "$all_nodes" | while read -r node_name; do
            [ -z "$node_name" ] && continue
            local encoded_node=$(printf '%s' "$node_name" | sed 's/ /%20/g')
            local delay=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies/${encoded_node}/delay?timeout=${test_timeout}&url=${test_url}" 2>/dev/null | "$BIN_YQ" '.delay // 0')
            if [ "$delay" = "0" ] || [ -z "$delay" ]; then
                printf "%-8s %s\n" "TIMEOUT" "$node_name" >> "$result_file"
            else
                printf "%-8s %s\n" "${delay}ms" "$node_name" >> "$result_file"
            fi
        done
        
        echo "========== 测试结果 =========="
        if [ "$sort_by_delay" = true ]; then
            grep -v "TIMEOUT" "$result_file" | sort -t'm' -k1 -n
            grep "TIMEOUT" "$result_file" 2>/dev/null || true
        else
            cat "$result_file"
        fi
        rm -f "$result_file"
    else
        echo "测试策略组: $selector (当前节点)"
        echo "URL: $test_url, 超时: ${test_timeout}ms"
        curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies/${encoded_name}/delay?timeout=${test_timeout}&url=${test_url}" 2>/dev/null | "$BIN_YQ" -P
    fi
}

# 节点排行榜
_clashtest_nodes() {
    _clashstatus >&/dev/null || {
        _failcat "$KERNEL_NAME 未运行"
        return 1
    }
    _detect_ext_addr
    
    local secret=$(_get_secret)
    local api_base="http://${EXT_IP}:${EXT_PORT}"
    
    echo ""
    echo "========== 节点速度排行榜 =========="
    echo "正在测试所有节点，请稍候..."
    echo ""
    
    local all_nodes=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies" 2>/dev/null | "$BIN_YQ" -o=tsv '.proxies | to_entries[] | select(.value.type != "Selector") | [.key, .value.type]')
    local result_file=$(mktemp)
    
    echo "$all_nodes" | while IFS=$'\t' read -r name type; do
        [ -z "$name" ] && continue
        local encoded_name=$(printf '%s' "$name" | sed 's/ /%20/g')
        local delay=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies/${encoded_name}/delay?timeout=3000&url=http://www.gstatic.com/generate_204" 2>/dev/null | "$BIN_YQ" '.delay // 99999')
        if [ "$delay" != "99999" ]; then
            printf "%-6s %s (%s)\n" "${delay}ms" "$name" "$type" >> "$result_file"
        else
            printf "%-6s %s (%s)\n" "TIMEOUT" "$name" "$type" >> "$result_file"
        fi
    done
    
    echo "排名    延迟     节点名称"
    echo "========================="
    grep -v "TIMEOUT" "$result_file" | sort -t'm' -k1 -n | head -10 | nl -w2 -s".  "
    echo ""
    echo "超时节点: $(grep -c "TIMEOUT" "$result_file" 2>/dev/null || echo 0)"
    rm -f "$result_file"
}

# 字节转换为人类可读格式
_human_readable_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1024}")KB"
    elif [ "$size" -lt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1048576}")MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $size/1073741824}")GB"
    fi
}

# 记录统计数据
_record_stats() {
    local stats_file="${CLASH_RESOURCES_DIR}/.stats"
    mkdir -p "$stats_file"
    
    # 流量统计文件
    local traffic_file="${stats_file}/traffic"
    
    # 节点使用时长统计
    local node_usage_file="${stats_file}/node_usage"
    
    echo "$stats_file"
}

_clashstats() {
    _clashstatus >&/dev/null || {
        _failcat "$KERNEL_NAME 未运行，请先执行 clashctl on"
        return 1
    }
    _detect_ext_addr
    local secret=$(_get_secret)
    local api_base="http://${EXT_IP}:${EXT_PORT}"
    local stats_dir=$(_record_stats)
    local output_format="text"  # text 或 json
    
    # 检查参数
    for arg in "$@"; do
        case "$arg" in
        --json|-j)
            output_format="json"
            ;;
        esac
    done
    
    case "$1" in
    traffic|flow)
        # 流量统计
        local data=$(curl -s --noproxy "*" \
            -H "Authorization: Bearer ${secret}" \
            "${api_base}/traffic" 2>/dev/null)
        
        if [ "$output_format" = "json" ]; then
            echo "$data" | "$BIN_YQ" -P
        else
            local up=$(echo "$data" | "$BIN_YQ" '.up // 0')
            local down=$(echo "$data" | "$BIN_YQ" '.down // 0')
            
            echo ""
            echo "========== 流量统计 =========="
            echo "上传:   $(_human_readable_size "$up")"
            echo "下载:   $(_human_readable_size "$down")"
            echo "总计:   $(_human_readable_size $((up + down)))"
            echo ""
            
            # 保存到历史记录
            local today=$(date +%Y-%m-%d)
            local traffic_file="${stats_dir}/traffic"
            echo "${today} ${up} ${down}" >> "$traffic_file"
            
            # 显示近7天历史
            if [ -f "$traffic_file" ]; then
                echo "近7天流量（每日更新）:"
                tail -7 "$traffic_file" | while read -r date up down; do
                    printf "  %s  ↑%10s  ↓%10s\n" "$date" "$(_human_readable_size "$up")" "$(_human_readable_size "$down")"
                done
            fi
        fi
        ;;
    connections|conn)
        # 连接统计
        local data=$(curl -s --noproxy "*" \
            -H "Authorization: Bearer ${secret}" \
            "${api_base}/connections" 2>/dev/null)
        
        if [ "$output_format" = "json" ]; then
            echo "$data" | "$BIN_YQ" -P
        else
            local total=$(echo "$data" | "$BIN_YQ" '. | length // 0')
            local downloading=$(echo "$data" | "$BIN_YQ" '[.[] | select(.chains[-1] != "DIRECT")] | length // 0')
            local direct=$(echo "$data" | "$BIN_YQ" '[.[] | select(.chains[-1] == "DIRECT")] | length // 0')
            
            echo ""
            echo "========== 连接统计 =========="
            echo "总连接:     $total"
            echo "代理连接:   $downloading"
            echo "直连:       $direct"
            echo ""
            
            # 显示最多连接的目标地址
            echo "最活跃的连接目标:"
            echo "$data" | "$BIN_YQ" -o=tsv '.[] | [.metadata.host // .metadata.destinationIP, .metadata.destinationPort]' 2>/dev/null | \
                sort | uniq -c | sort -rn | head -5 | \
                while read -r count host port; do
                    printf "  %3d  %s:%s\n" "$count" "$host" "$port"
                done
        fi
        ;;
    node|nodes)
        # 节点使用统计
        local node_stats_file="${stats_dir}/node_history"
        
        # 获取当前所有策略组的选中节点
        local data=$(curl -s --noproxy "*" \
            -H "Authorization: Bearer ${secret}" \
            "${api_base}/proxies" 2>/dev/null)
        
        if [ "$output_format" = "json" ]; then
            echo "$data" | "$BIN_YQ" '[.proxies | to_entries[] | select(.value.type == "Selector") | {name: .key, now: .value.now, all: .value.all, history: .value.history}]'
        else
            echo ""
            echo "========== 节点使用统计 =========="
            echo ""
            
            # 输出当前各策略组状态
            echo "$data" | "$BIN_YQ" -o=tsv '.proxies | to_entries[] | select(.value.type == "Selector") | [.key, .value.now, (.value.history | length)]' 2>/dev/null | \
                while IFS=$'\t' read -r name current history_count; do
                    printf "%-20s → %-20s (切换次数: %s)\n" "$name" "$current" "${history_count:-0}"
                done
            
            # 记录当前状态
            local now=$(date +%s)
            echo "$data" | "$BIN_YQ" -o=tsv '.proxies | to_entries[] | select(.value.type == "Selector") | [.key, .value.now]' 2>/dev/null | \
                while IFS=$'\t' read -r name node; do
                    echo "$now $name $node" >> "$node_stats_file"
                done
        fi
        ;;
    all|*)
        # 显示所有统计
        _clashstats traffic "$@"
        echo ""
        _clashstats connections "$@"
        echo ""
        _clashstats node "$@"
        ;;
    esac
}


# ========== 订阅融合功能 ==========
_clashmerge() {
    local sub_ids=()
    local output_name=""
    local output_id=""
    
    while (($#)); do
        case "$1" in
        -o|--output)
            output_name="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'EOF'

订阅融合 - 将多个订阅的节点合并为一个配置

用法:
  clashctl merge <id1> <id2> ... -o <名称>

参数:
  -o, --output <名称>    输出订阅名称（必填）

示例:
  clashctl merge 1 2 3 -o "合并订阅"     # 合并订阅1、2、3

EOF
            return 0
            ;;
        [0-9]*)
            sub_ids+=("$1")
            shift
            ;;
        *)
            shift
            ;;
        esac
    done
    
    ((${#sub_ids[@]} == 0)) && {
        _failcat "请指定至少一个订阅ID"
        return 1
    }
    
    [ -z "$output_name" ] && {
        _failcat "请指定输出名称: -o <名称>"
        return 1
    }
    
    _okcat "开始融合 ${#sub_ids[@]} 个订阅..."
    
    local tmp_dir=$(mktemp -d)
    local merged_proxies="${tmp_dir}/proxies.yaml"
    
    echo "proxies: []" > "$merged_proxies"
    
    local idx=1
    for id in "${sub_ids[@]}"; do
        local url=$(_get_url_by_id "$id")
        [ -z "$url" ] && {
            _failcat "订阅 #$id 不存在"
            rm -rf "$tmp_dir"
            return 1
        }
        
        local tmp_config="${tmp_dir}/sub_${idx}.yaml"
        _okcat "下载订阅 #$id..."
        _download_config "$tmp_config" "$url" || {
            _failcat "订阅 #$id 下载失败"
            rm -rf "$tmp_dir"
            return 1
        }
        
        "$BIN_YQ" -i '.proxies // []' "$tmp_config" 2>/dev/null
        if [ -s "$tmp_config" ]; then
            "$BIN_YQ" -i "with(.proxies; . + load(\"$tmp_config\").proxies | unique_by(.name))" "$merged_proxies"
        fi
        ((idx++))
    done
    
    local all_proxy_names=$("$BIN_YQ" '.proxies // [] | map(.name)' "$merged_proxies")
    local final_config="${tmp_dir}/final.yaml"
    
    cat > "$final_config" <<EOF
proxies: $("$BIN_YQ" '.proxies' "$merged_proxies")
proxy-groups:
  - name: "🚀 融合节点"
    type: select
    proxies: ${all_proxy_names}
  - name: "🌐 全局"
    type: select
    proxies:
      - "🚀 融合节点"
      - "DIRECT"
rules:
  - MATCH,"🚀 融合节点"
EOF
    
    if ! _valid_config "$final_config"; then
        _failcat "合并后的配置验证失败"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    output_id=$(_sub_add_manual "$output_name" "$final_config")
    rm -rf "$tmp_dir"
    
    _okcat "融合完成: [$output_name] (ID: $output_id)"
    _okcat "共 $("$BIN_YQ" '.proxies | length' "$final_config") 个节点"
    echo ""
    echo "使用: clashctl sub use $output_id"
}

_sub_add_manual() {
    local name="$1"
    local config_file="$2"
    local id=$("$BIN_YQ" '.profiles // [] | (map(.id) | max) // 0 | . + 1' "$CLASH_PROFILES_META")
    local profile_path="${CLASH_PROFILES_DIR}/${id}.yaml"
    
    mkdir -p "$CLASH_PROFILES_DIR"
    cp "$config_file" "$profile_path"
    
    "$BIN_YQ" -i ".profiles += [{id: $id, url: \"file://$profile_path\", name: \"$name\", updated: \"$(date -Iseconds)\"}]" "$CLASH_PROFILES_META"
    
    echo "$id"
}

# ========== node test 子命令 ==========
_clashnode_test() {
    _clashstatus >&/dev/null || { _failcat "$KERNEL_NAME 未运行"; return 1; }
    _detect_ext_addr
    
    local selector_input="${1:-}"
    [ -z "$selector_input" ] && { _failcat "请指定策略组: clashctl node test <#策略组> [options]"; return 1; }
    shift
    
    local cache_dir="${CLASH_RESOURCES_DIR}/.cache"
    local selector_cache="${cache_dir}/selectors"
    local node_cache="${cache_dir}/nodes"
    local selector=$(echo "$selector_input" | sed 's/^#//')
    if [[ "$selector" =~ ^[0-9]+$ ]] && [ -f "$selector_cache" ]; then
        selector=$(awk -F'\t' -v n="$selector" '$1 == n {print $2; exit}' "$selector_cache" 2>/dev/null)
    fi
    [ -z "$selector" ] && { _failcat "无效的策略组: $selector_input"; return 1; }
    
    local test_all=false
    local sort_by_delay=false
    local show_rank=false
    
    while (($#)); do
        case "$1" in
            --all|-a) test_all=true; shift ;;
            --sort|-s) sort_by_delay=true; shift ;;
            --rank|-r) show_rank=true; shift ;;
            *) shift ;;
        esac
    done
    
    local secret=$(_get_secret)
    local api_base="http://${EXT_IP}:${EXT_PORT}"
    local encoded_name=$(printf '%s' "$selector" | sed 's/ /%20/g')
    
    if [ "$test_all" = true ] || [ "$show_rank" = true ]; then
        echo "测试策略组: $selector (所有节点)"
        local all_nodes=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies/${encoded_name}" 2>/dev/null | "$BIN_YQ" '.all // [] | .[]')
        [ -z "$all_nodes" ] && { _failcat "获取节点列表失败"; return 1; }
        
        # 建立节点名到ID的映射
        local node_id_map=$(mktemp)
        if [ -f "$node_cache" ]; then
            cat "$node_cache" > "$node_id_map"
        fi
        
        local result_file=$(mktemp)
        local idx=1
        echo "$all_nodes" | while read -r node_name; do
            [ -z "$node_name" ] && continue
            local encoded_node=$(printf '%s' "$node_name" | sed 's/ /%20/g')
            local delay=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies/${encoded_node}/delay?timeout=3000&url=http://www.gstatic.com/generate_204" 2>/dev/null | "$BIN_YQ" '.delay // 0')
            
            # 查找节点ID
            local node_id=""
            if [ -f "$node_cache" ]; then
                node_id=$(awk -F'\t' -v name="$node_name" '$2 == name {print "@"$1; exit}' "$node_cache" 2>/dev/null)
            fi
            [ -z "$node_id" ] && node_id="@$idx"
            
            if [ "$delay" = "0" ] || [ -z "$delay" ]; then
                printf "%-8s %-6s %s\n" "TIMEOUT" "$node_id" "$node_name" >> "$result_file"
            else
                printf "%-8s %-6s %s\n" "${delay}ms" "$node_id" "$node_name" >> "$result_file"
            fi
            ((idx++))
        done
        
        echo "========== 测试结果 =========="
        if [ "$show_rank" = true ] || [ "$sort_by_delay" = true ]; then
            echo "排名    延迟     ID     节点名称"
            echo "======================================"
            grep -v "TIMEOUT" "$result_file" | sort -t'm' -k1 -n | head -10 | nl -w2 -s".  "
            local timeout_count=$(grep -c "TIMEOUT" "$result_file" 2>/dev/null || echo 0)
            [ "$timeout_count" -gt 0 ] && echo "超时节点: $timeout_count"
        else
            echo "延迟     ID     节点名称"
            echo "======================================"
            cat "$result_file"
        fi
        rm -f "$result_file" "$node_id_map"
    else
        echo "测试策略组: $selector (当前节点)"
        curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "${api_base}/proxies/${encoded_name}/delay?timeout=3000&url=http://www.gstatic.com/generate_204" 2>/dev/null | "$BIN_YQ" -P
    fi
}

# ========== net 命令 - 网络诊断 ==========
_clashnet() {
    case "$1" in
    ping)
        shift
        _clashnet_ping "$@"
        ;;
    dns)
        shift
        _clashnet_dns "$@"
        ;;
    traffic)
        _clashnet_traffic
        ;;
    conn)
        _clashnet_conn
        ;;
    *)
        cat <<'EOF'

net - 网络诊断

用法:
  clashctl net ping [--proxy|--direct]    # 网络连通测试
  clashctl net dns [domain]               # DNS解析测试
  clashctl net traffic                    # 流量统计
  clashctl net conn                       # 连接统计

EOF
        ;;
    esac
}

_clashnet_ping() {
    local mixed_port=$("$BIN_YQ" '.mixed-port // 7890' "$CLASH_CONFIG_RUNTIME")
    local proxy_url="http://127.0.0.1:${mixed_port}"
    
    case "$1" in
    --proxy)
        echo "=== 测试代理连通性 ==="
        curl -s --proxy "$proxy_url" --max-time 5 http://ip-api.com/json 2>/dev/null | "$BIN_YQ" -P '{ip: .query, country: .country, isp: .isp}' || _failcat "代理测试失败"
        ;;
    --direct)
        echo "=== 测试直连连通性 ==="
        curl -s --max-time 5 http://ip-api.com/json 2>/dev/null | "$BIN_YQ" -P '{ip: .query, country: .country, isp: .isp}' || _failcat "直连测试失败"
        ;;
    *)
        echo "========== 网络诊断 =========="
        echo ""
        _clashnet_ping --direct
        echo ""
        _clashstatus >&/dev/null && _clashnet_ping --proxy || _failcat "代理未运行"
        echo ""
        ;;
    esac
}

_clashnet_dns() {
    local domain="${1:-www.google.com}"
    echo "=== DNS 解析测试: $domain ==="
    dig @127.0.0.1 -p 1053 "$domain" +short 2>/dev/null || nslookup "$domain" 127.0.0.1 2>/dev/null || _failcat "DNS 解析失败"
}

_clashnet_traffic() {
    _clashstatus >&/dev/null || { _failcat "代理未运行"; return 1; }
    _detect_ext_addr
    
    local secret=$(_get_secret)
    local data=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "http://${EXT_IP}:${EXT_PORT}/traffic" 2>/dev/null)
    local up=$(echo "$data" | "$BIN_YQ" '.up // 0')
    local down=$(echo "$data" | "$BIN_YQ" '.down // 0')
    
    echo "上传: $(_human_readable_size "$up")"
    echo "下载: $(_human_readable_size "$down")"
    echo "总计: $(_human_readable_size $((up + down)))"
}

_clashnet_conn() {
    _clashstatus >&/dev/null || { _failcat "代理未运行"; return 1; }
    _detect_ext_addr
    
    local secret=$(_get_secret)
    local data=$(curl -s --noproxy "*" -H "Authorization: Bearer ${secret}" "http://${EXT_IP}:${EXT_PORT}/connections" 2>/dev/null)
    local total=$(echo "$data" | "$BIN_YQ" '. | length // 0')
    
    echo "总连接: $total"
}

# ========== sys 命令 - 系统维护 ==========
_clashsys() {
    case "$1" in
    upgrade)
        shift
        _clashupgrade "$@"
        ;;
    log)
        shift
        placeholder_log "$@"
        ;;
    *)
        cat <<'EOF'

sys - 系统维护

用法:
  clashctl sys upgrade                    # 升级内核
  clashctl sys log                        # 查看日志

EOF
        ;;
    esac
}
