#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 6 — phpLDAPadmin${RESET}"; echo ""

# 6.1 Apache is running (serves phpLDAPadmin)
apache_status=$(ssh_server "systemctl is-active apache2 2>/dev/null" || echo "unknown")
assert_contains "Apache is active" "$apache_status" "active"

# 6.2 Port 80 listening
ports=$(ssh_server "ss -tlnp 2>/dev/null")
assert_contains "Port 80 listening" "$ports" ":80"

# 6.3 phpLDAPadmin accessible locally
page=$(ssh_server "curl -s -L http://localhost/phpldapadmin/ 2>/dev/null | head -20" || echo "")
assert_contains "phpLDAPadmin accessible" "$page" "phpLDAPadmin|ldap|LDAP"

# 6.4 Via host port (if available)
if [[ -n "$HTTP_PORT" ]]; then
    host_page=$(curl -s --connect-timeout 3 "http://localhost:${HTTP_PORT}/phpldapadmin/" 2>/dev/null | head -20 || echo "")
    assert_contains "phpLDAPadmin via host port" "$host_page" "phpLDAPadmin|ldap|html"
fi

# Cleanup: reset demo state
cleanup_demo
setup_demo

report_results "Exercise 6"
