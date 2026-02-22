#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 5 — Authentication${RESET}"; echo ""

# Ensure demo data exists
setup_demo

# 5.1 ldapwhoami with admin credentials
whoami=$(ssh_server "ldapwhoami -x -D 'cn=admin,dc=ldap-lab,dc=local' -w admin -H ldap://localhost 2>/dev/null" || echo "")
assert_contains "Admin can authenticate" "$whoami" "dn:cn=admin"

# 5.2 slapcat works (dump directory)
dump=$(ssh_server "sudo slapcat 2>/dev/null | head -20")
assert_contains "slapcat dumps directory" "$dump" "dc=ldap-lab,dc=local"

# 5.3 Anonymous search works
anon=$(ssh_server "ldapsearch -x -H ldap://localhost -b 'dc=ldap-lab,dc=local' -LLL '(uid=alice)' dn 2>/dev/null" || echo "")
assert_contains "Anonymous search finds alice" "$anon" "uid=alice"

report_results "Exercise 5"
