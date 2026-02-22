#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
echo ""; echo "${BOLD}Exercise 3 — LDIF Operations${RESET}"; echo ""

# Ensure demo data exists
setup_demo

# 3.1 Add a new user via LDIF
ssh_server "ldapadd -x -D 'cn=admin,dc=ldap-lab,dc=local' -w admin << 'EOF'
dn: uid=testuser,ou=users,dc=ldap-lab,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: testuser
sn: Test
cn: Test User
uidNumber: 10099
gidNumber: 10000
homeDirectory: /home/testuser
loginShell: /bin/bash
userPassword: test123
EOF" >/dev/null 2>&1

result=$(ldap_search "(uid=testuser)" dn 2>/dev/null || echo "")
assert_contains "testuser added" "$result" "uid=testuser"

# 3.2 Modify the user
ssh_server "ldapmodify -x -D 'cn=admin,dc=ldap-lab,dc=local' -w admin << 'EOF'
dn: uid=testuser,ou=users,dc=ldap-lab,dc=local
changetype: modify
replace: sn
sn: Modified
EOF" >/dev/null 2>&1

modified=$(ldap_search "(uid=testuser)" sn 2>/dev/null || echo "")
assert_contains "testuser modified" "$modified" "Modified"

# 3.3 Delete the user
ssh_server "ldapdelete -x -D 'cn=admin,dc=ldap-lab,dc=local' -w admin 'uid=testuser,ou=users,dc=ldap-lab,dc=local'" >/dev/null 2>&1
deleted=$(ldap_search "(uid=testuser)" dn 2>/dev/null || echo "no results")
assert_not_contains "testuser deleted" "$deleted" "dn: uid=testuser"

report_results "Exercise 3"
