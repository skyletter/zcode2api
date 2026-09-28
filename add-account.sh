#!/usr/bin/env bash
# add-account.sh —— zcode2api 容器内账号管理（Z.AI OAuth 登录）
#
# 用法（宿主机 SSH 执行）:
#   docker exec -it zcode2api /app/add-account.sh
#
# 流程:
#   1. 脚本打印一条 Z.AI 授权链接
#   2. 把链接复制到你自己电脑的浏览器打开，完成登录/授权
#   3. 授权完成后无需任何操作，脚本会自动轮询到结果并把账号存入池
#
# 说明: 本流程为服务端中介轮询（server-mediated），授权结果由 Z.AI 挂在本次
#       流程 ID 上，脚本轮询取回，因此不需要复制回调地址。
set -euo pipefail

cd /app

C='\033[36m'; G='\033[32m'; Y='\033[33m'; N='\033[0m'
echo_c() { printf "%b%s%b\n" "$1" "$2" "$N"; }

echo_c "$C" "=============================================="
echo_c "$C" "  zcode2api —— 添加 Z.AI 账号（OAuth 登录）"
echo_c "$C" "=============================================="
echo
echo "接下来请："
echo "  1. 复制下方链接，粘贴到你自己电脑的浏览器打开"
echo "  2. 完成登录 / 授权"
echo "  3. 回到这里等待，脚本会自动完成入池（无需粘贴任何回调地址）"
echo
echo_c "$Y" "提示: 首次使用海外邮箱 / Google 账号时，若授权页只有手机号登录，"
echo_c "$Y" "      请先在浏览器打开 https://chat.z.ai/auth?redirect_uri=https://z.ai/ 完成预登录，"
echo_c "$Y" "      再打开下面的授权链接。"
echo

before="$(python cli.py accounts 2>/dev/null || true)"

python cli.py login zai --no-browser || echo_c "$Y" "⚠️ 登录流程异常退出"

echo
echo_c "$G" "当前账号列表:"
python cli.py accounts

after="$(python cli.py accounts 2>/dev/null || true)"
if [ "$before" = "$after" ]; then
  echo
  echo_c "$Y" "⚠️ 未检测到新账号。"
  echo_c "$Y" "   若你尚未在浏览器完成授权，请重新执行本脚本（等待上限约 3 分钟）。"
fi

if [ "${1:-}" = "quota" ]; then
  echo
  python cli.py quota
fi