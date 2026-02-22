#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 1 — LDAP Anatomy${RESET}"; echo ""

# 1.1 slapd is running
status=$(ssh_server "systemctl is-active slapd 2>/dev/null" || echo "unknown")
assert_contains "slapd is active" "$status" "active"

# 1.2 LDAP port listening
ports=$(ssh_server "ss -tlnp 2>/dev/null")
assert_contains "Port 389 listening" "$ports" ":389"

# 1.3 ldap-utils installed on server
assert "ldapsearch on server" ssh_server "which ldapsearch"

# 1.4 ldap-utils installed on client
assert "ldapsearch on client" ssh_client "which ldapsearch"

# 1.5 Demo scripts exist
assert "demo-setup.sh exists" ssh_server "test -f ~/demo-setup.sh"
assert "demo-cleanup.sh exists" ssh_server "test -f ~/demo-cleanup.sh"

# 1.6 Run demo setup
setup_demo
result=$(ldap_search "(objectClass=*)" dn 2>/dev/null || echo "")
assert_contains "Base DN exists after setup" "$result" "dc=ldap-lab,dc=local"

report_results "Exercise 1"
