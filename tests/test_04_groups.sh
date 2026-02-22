#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 4 — Groups${RESET}"; echo ""

# Ensure demo data exists
setup_demo

# 4.1 Developers group exists
group=$(ldap_search "(cn=developers)" 2>/dev/null || echo "")
assert_contains "developers group exists" "$group" "cn=developers"

# 4.2 Group has members
assert_contains "alice is a member" "$group" "memberUid.*alice|alice"
assert_contains "bob is a member" "$group" "memberUid.*bob|bob"

# 4.3 OUs exist
ou_users=$(ldap_search "(ou=users)" dn 2>/dev/null || echo "")
assert_contains "ou=users exists" "$ou_users" "ou=users"

ou_groups=$(ldap_search "(ou=groups)" dn 2>/dev/null || echo "")
assert_contains "ou=groups exists" "$ou_groups" "ou=groups"

report_results "Exercise 4"
