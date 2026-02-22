#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 2 — LDAP Searching${RESET}"; echo ""

# Ensure demo data exists
setup_demo

# 2.1 Search for all entries
all=$(ldap_search "(objectClass=*)" dn 2>/dev/null || echo "")
assert_contains "Can search all entries" "$all" "dn:"

# 2.2 Search for alice
alice=$(ldap_search "(uid=alice)" 2>/dev/null || echo "")
assert_contains "Found alice" "$alice" "uid=alice"
assert_contains "Alice has email" "$alice" "mail.*alice"

# 2.3 Search for users OU
users=$(ldap_search "(ou=users)" 2>/dev/null || echo "")
assert_contains "Found users OU" "$users" "ou=users"

# 2.4 Search from client
client_result=$(ssh_client "ldapsearch -x -H ldap://192.168.100.1 -b 'dc=ldap-lab,dc=local' '(uid=bob)' 2>/dev/null" || echo "")
assert_contains "Client can query server" "$client_result" "uid=bob"

# 2.5 Search with filter
devs=$(ldap_search "(cn=developers)" 2>/dev/null || echo "")
assert_contains "Found developers group" "$devs" "cn=developers"

report_results "Exercise 2"
