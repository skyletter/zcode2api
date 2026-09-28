#!/usr/bin/env bash
# add-account.sh —— zcode2api 容器内账号管理（从宿主机用 docker exec 调用）
# 示例：docker exec -it traework2api /app/add-account.sh
set -euo pipefail

cd /app

R='\033[31m'; G='\033[32m'; Y='\033[33m'; C='\033[36m'; B='\033[1m'; N='\033[0m'

echo_e() { printf "%b%s%b\n" "$1" "$2" "$N"; }

usage() {
  cat <<'EOF'
用法（宿主机执行请加前缀 docker exec -it traework2api）:
  /app/add-account.sh                                  交互式添加账号（推荐）
  /app/add-account.sh zai <名字> <JWT|APIKey>          直接添加 Z.AI 账号
  /app/add-account.sh bigmodel <名字> <APIKey>         直接添加智谱 bigmodel API Key
  /app/add-account.sh login                            Z.AI OAuth 登录（打印链接，电脑浏览器授权）
  /app/add-account.sh list [zai|bigmodel]              查看账号列表
  /app/add-account.sh quota                            查询 JWT 账号实时额度
  /app/add-account.sh status                           查看配置与账号概览
  /app/add-account.sh remove <zai|bigmodel> <id|名字>  删除账号

账号类型说明:
  zai + JWT      —— Coding Plan / Start Plan 额度（走验证码求解器）
  zai + API Key  —— Z.AI API Key（回退通道，免验证码）
  bigmodel + Key —— 智谱开放平台 API Key（免验证码）
EOF
}

do_add() {
  local provider="$1" name="$2" secret="$3"
  if [ "$provider" != "zai" ] && [ "$provider" != "bigmodel" ]; then
    echo_e "$R" "provider 只能是 zai 或 bigmodel"; usage; exit 2
  fi
  echo_e "$C" "⏳ 添加账号并初始化（安装序 + 自动领取，可能需要几十秒）..."
  python cli.py add-account "$provider" "$name" "$secret"
  echo
  python cli.py accounts
}

interactive() {
  if [ ! -t 0 ]; then
    echo_e "$R" "当前不是交互终端，请改用参数模式：add-account.sh zai <名字> <凭据>"
    exit 2
  fi
  echo_e "$B" "zcode2api 添加账号"
  echo "  1) zai      —— Z.AI（Coding Plan JWT 或 API Key）"
  echo "  2) bigmodel —— 智谱开放平台 API Key"
  local choice provider name secret
  read -r -p "选择 [1/2，默认 1]: " choice
  case "${choice:-1}" in
    1|zai) provider="zai" ;;
    2|bigmodel) provider="bigmodel" ;;
    *) echo_e "$R" "无效选择"; exit 2 ;;
  esac
  read -r -p "账号名称（回车默认 auto-$(date +%m%d-%H%M)）: " name
  name="${name:-auto-$(date +%m%d-%H%M)}"
  read -r -s -p "粘贴 JWT 或 API Key（不回显，粘贴后回车）: " secret
  echo
  if [ -z "$secret" ]; then
    echo_e "$R" "凭据为空，已取消"; exit 2
  fi
  if [ "$provider" = "zai" ] && [ "$(printf '%s' "$secret" | awk -F. '{print NF}')" = "3" ]; then
    echo_e "$C" "检测到 JWT（3 段点分），按 Coding Plan 通道添加"
  fi
  do_add "$provider" "$name" "$secret"
}

case "${1:-}" in
  "")
    interactive
    ;;
  zai|bigmodel)
    if [ "$#" -lt 3 ]; then usage; exit 2; fi
    do_add "$1" "$2" "$3"
    ;;
  login)
    echo_e "$C" "即将打印授权链接：复制到电脑浏览器打开完成授权（脚本等待约 3 分钟）"
    python cli.py login zai --no-browser
    echo
    python cli.py accounts
    ;;
  list)
    if [ "${2:-}" = "zai" ] || [ "${2:-}" = "bigmodel" ]; then
      python cli.py accounts "$2"
    else
      python cli.py accounts
    fi
    ;;
  quota)
    python cli.py quota
    ;;
  status)
    python cli.py status
    ;;
  remove)
    if [ "$#" -lt 3 ]; then usage; exit 2; fi
    python cli.py remove-account "$2" "$3"
    echo
    python cli.py accounts
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage; exit 2
    ;;
esac