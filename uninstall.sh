#!/usr/bin/env bash

THIS_SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE:-${(%):-%N}}")")
cd "$THIS_SCRIPT_DIR" || exit 1

. scripts/cmd/clashctl.sh
. scripts/preflight.sh

[ -n "$CLASH_BASE_DIR" ] && [ "$CLASH_BASE_DIR" != "/" ] || {
  _error_quit "安装路径异常，已停止卸载"
  exit 1
}

clashctl proxy off >/dev/null 2>&1 || true
_uninstall_service >/dev/null 2>&1 || true
_revoke_rc

/bin/rm -rf "$CLASH_BASE_DIR"
_okcat '卸载完成'
