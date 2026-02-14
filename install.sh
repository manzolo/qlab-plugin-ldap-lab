#!/usr/bin/env bash
# ldap-lab install script

set -euo pipefail

echo ""
echo "  [ldap-lab] Installing..."
echo ""
echo "  This plugin creates two VMs for practicing LDAP directory services:"
echo ""
echo "    1. ldap-lab-server  — OpenLDAP Server VM"
echo "       Runs slapd (OpenLDAP) and phpLDAPadmin"
echo "       Practice directory configuration and management"
echo ""
echo "    2. ldap-lab-client  — LDAP Client VM"
echo "       Uses ldap-utils to query and modify the directory"
echo "       Practice ldapsearch, ldapadd, ldapmodify, ldapdelete"
echo ""
echo "  What you will learn:"
echo "    - How LDAP directory services work (DIT, DN, entries, attributes)"
echo "    - How to configure OpenLDAP (slapd) with a custom domain"
echo "    - How to create organizational units (OUs), users, and groups"
echo "    - How to query the directory with ldapsearch and filters"
echo "    - How to manage entries with ldapadd, ldapmodify, ldapdelete"
echo "    - How to use phpLDAPadmin as a web-based LDAP browser"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [ldap-lab] Installation complete."
echo "  Run with: qlab run ldap-lab"
