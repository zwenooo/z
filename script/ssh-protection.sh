#!/bin/bash
# SSH安全防护一键安装脚本
# 适用于新服务器，执行一次即可

set -e

echo "========================================"
echo "  SSH安全防护自动配置脚本"
echo "========================================"

# 1. 安装必要软件
echo "[1/6] 安装fail2ban和ipset..."
apt update -qq
apt install -y fail2ban ipset >/dev/null 2>&1

# 2. 配置fail2ban
echo "[2/6] 配置fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
banaction = iptables-ipset-proto6-allports
bantime = -1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = -1
findtime = 600
EOF

# 3. 设置使用DROP而不是REJECT
echo "[3/6] 优化封禁方式..."
cat > /etc/fail2ban/action.d/iptables-common.local << 'EOF'
[Init]
blocktype = DROP
EOF

# 4. 清理旧数据并重启
echo "[4/6] 重启fail2ban服务..."
systemctl stop fail2ban 2>/dev/null || true
rm -f /var/lib/fail2ban/fail2ban.sqlite3
systemctl start fail2ban
systemctl enable fail2ban >/dev/null 2>&1

# 5. 等待fail2ban扫描日志
echo "[5/6] 等待fail2ban扫描日志..."
sleep 5

# 6. 断开已被封禁IP的现有连接（支持IPv4和IPv6）
echo "[6/6] 清理恶意连接..."
fail2ban-client status sshd 2>/dev/null | \
  grep "Banned IP list" | \
  cut -d: -f2 | \
  tr ' ' '\n' | \
  grep -v '^$' | \
  while read ip; do
    if [[ -n "$ip" ]]; then
      ss -K dst "$ip" 2>/dev/null || true
    fi
  done

# 完成
echo ""
echo "========================================"
echo "  ✓ 配置完成！"
echo "========================================"
echo ""
echo "当前状态："
fail2ban-client status sshd
echo ""
echo "常用命令："
echo "  查看状态: fail2ban-client status sshd"
echo "  查看日志: tail -f /var/log/fail2ban.log"
echo "  解封IP:   fail2ban-client set sshd unbanip <IP>"
echo ""