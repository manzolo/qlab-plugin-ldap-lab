#!/usr/bin/env bash
# ldap-lab run script — boots two VMs for LDAP directory services labs

set -euo pipefail

PLUGIN_NAME="ldap-lab"
SERVER_VM="ldap-lab-server"
CLIENT_VM="ldap-lab-client"

# Internal LAN — direct VM-to-VM link via QEMU socket multicast
INTERNAL_MCAST="230.0.0.1:10003"
SERVER_INTERNAL_IP="192.168.100.1"
CLIENT_INTERNAL_IP="192.168.100.2"
SERVER_LAN_MAC="52:54:00:00:04:01"
CLIENT_LAN_MAC="52:54:00:00:04:02"

# LDAP configuration
LDAP_DOMAIN="ldap-lab.local"
LDAP_BASE_DN="dc=ldap-lab,dc=local"

echo "============================================="
echo "  ldap-lab: LDAP Directory Services Lab"
echo "============================================="
echo ""
echo "  This lab creates two VMs connected by an"
echo "  internal LAN (192.168.100.0/24):"
echo ""
echo "    1. $SERVER_VM"
echo "       Static IP: $SERVER_INTERNAL_IP"
echo "       Runs OpenLDAP (slapd) + phpLDAPadmin"
echo ""
echo "    2. $CLIENT_VM"
echo "       Static IP: $CLIENT_INTERNAL_IP"
echo "       LDAP client with ldap-utils"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 1024)}"

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# =============================================
# Step 1: Download cloud image (shared by both VMs)
# =============================================
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  Both VMs will share the same base image via overlay disks."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# =============================================
# Step 2: Cloud-init configurations
# =============================================
info "Step 2: Cloud-init configuration for both VMs"
echo ""

# --- LDAP Server VM cloud-init ---
info "Creating cloud-init for $SERVER_VM..."
cat > "$LAB_DIR/user-data-server" <<'USERDATA'
#cloud-config
hostname: ldap-lab-server
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
debconf_selections: |
  slapd slapd/no_configuration boolean true
packages:
  - slapd
  - ldap-utils
  - phpldapadmin
  - nano
  - net-tools
  - iputils-ping
  - tcpdump
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          ldaplan:
            match:
              macaddress: "52:54:00:00:04:01"
            addresses:
              - 192.168.100.1/24
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mldap-lab-server\033[0m — \033[1mOpenLDAP Server Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  OpenLDAP Server + phpLDAPadmin
        \033[1;33mStatic IP:\033[0m  \033[1;36m192.168.100.1\033[0m
        \033[1;33mBase DN:\033[0m    \033[1;36mdc=ldap-lab,dc=local\033[0m

        \033[1;33mDemo:\033[0m
          \033[0;32mbash ~/demo-setup.sh\033[0m       create domain + OU + 3 users
          \033[0;32mbash ~/demo-cleanup.sh\033[0m     remove everything, start fresh

        \033[1;33mUseful commands:\033[0m
          \033[0;32msudo slapcat\033[0m                            dump entire directory
          \033[0;32mldapsearch -x -H ldap://localhost -b "dc=ldap-lab,dc=local"\033[0m
          \033[0;32msudo systemctl status slapd\033[0m             check slapd service
          \033[0;32msudo dpkg-reconfigure slapd\033[0m             reconfigure domain

        \033[1;33mphpLDAPadmin:\033[0m
          From host browser: \033[1;36mhttp://localhost:8080/phpldapadmin\033[0m
          Login DN: \033[0;32mcn=admin,dc=ldap-lab,dc=local\033[0m
          Password: \033[0;32m(set during demo-setup.sh or dpkg-reconfigure)\033[0m

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


  - path: /home/labuser/demo-setup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # demo-setup.sh — Configure LDAP domain and create sample entries
      set -euo pipefail

      LDAP_DOMAIN="ldap-lab.local"
      LDAP_BASE_DN="dc=ldap-lab,dc=local"
      LDAP_ORG="LDAP Lab"
      ADMIN_PASS="admin"

      echo "============================================="
      echo "  LDAP Demo Setup"
      echo "============================================="
      echo ""
      echo "  Domain:   $LDAP_DOMAIN"
      echo "  Base DN:  $LDAP_BASE_DN"
      echo "  Admin DN: cn=admin,$LDAP_BASE_DN"
      echo "  Admin pw: $ADMIN_PASS"
      echo ""

      # Step 1: Reconfigure slapd with the lab domain
      echo "[1/5] Reconfiguring slapd with domain $LDAP_DOMAIN..."
      sudo debconf-set-selections <<EOF
      slapd slapd/no_configuration boolean false
      slapd slapd/domain string $LDAP_DOMAIN
      slapd slapd/purge_database boolean true
      slapd slapd/move_old_database boolean true
      slapd shared/organization string $LDAP_ORG
      slapd slapd/password1 password $ADMIN_PASS
      slapd slapd/password2 password $ADMIN_PASS
      slapd slapd/backend select MDB
      EOF
      sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive slapd
      echo "  Done."
      echo ""

      # Step 2: Create organizational units
      echo "[2/5] Creating organizational units..."
      ldapadd -x -D "cn=admin,$LDAP_BASE_DN" -w "$ADMIN_PASS" <<EOF
      dn: ou=users,$LDAP_BASE_DN
      objectClass: organizationalUnit
      ou: users

      dn: ou=groups,$LDAP_BASE_DN
      objectClass: organizationalUnit
      ou: groups
      EOF
      echo "  Created: ou=users and ou=groups"
      echo ""

      # Step 3: Create users
      echo "[3/5] Creating users (alice, bob, charlie)..."
      ALICE_PASS=$(slappasswd -s alice123)
      BOB_PASS=$(slappasswd -s bob123)
      CHARLIE_PASS=$(slappasswd -s charlie123)

      ldapadd -x -D "cn=admin,$LDAP_BASE_DN" -w "$ADMIN_PASS" <<EOF
      dn: uid=alice,ou=users,$LDAP_BASE_DN
      objectClass: inetOrgPerson
      objectClass: posixAccount
      objectClass: shadowAccount
      uid: alice
      sn: Smith
      givenName: Alice
      cn: Alice Smith
      displayName: Alice Smith
      uidNumber: 10001
      gidNumber: 10000
      homeDirectory: /home/alice
      loginShell: /bin/bash
      userPassword: $ALICE_PASS
      mail: alice@ldap-lab.local

      dn: uid=bob,ou=users,$LDAP_BASE_DN
      objectClass: inetOrgPerson
      objectClass: posixAccount
      objectClass: shadowAccount
      uid: bob
      sn: Jones
      givenName: Bob
      cn: Bob Jones
      displayName: Bob Jones
      uidNumber: 10002
      gidNumber: 10000
      homeDirectory: /home/bob
      loginShell: /bin/bash
      userPassword: $BOB_PASS
      mail: bob@ldap-lab.local

      dn: uid=charlie,ou=users,$LDAP_BASE_DN
      objectClass: inetOrgPerson
      objectClass: posixAccount
      objectClass: shadowAccount
      uid: charlie
      sn: Brown
      givenName: Charlie
      cn: Charlie Brown
      displayName: Charlie Brown
      uidNumber: 10003
      gidNumber: 10000
      homeDirectory: /home/charlie
      loginShell: /bin/bash
      userPassword: $CHARLIE_PASS
      mail: charlie@ldap-lab.local
      EOF
      echo "  Created: alice (alice123), bob (bob123), charlie (charlie123)"
      echo ""

      # Step 4: Create group
      echo "[4/5] Creating group 'developers'..."
      ldapadd -x -D "cn=admin,$LDAP_BASE_DN" -w "$ADMIN_PASS" <<EOF
      dn: cn=developers,ou=groups,$LDAP_BASE_DN
      objectClass: posixGroup
      cn: developers
      gidNumber: 10000
      memberUid: alice
      memberUid: bob
      memberUid: charlie
      EOF
      echo "  Created: cn=developers with members alice, bob, charlie"
      echo ""

      # Step 5: Summary
      echo "[5/5] Verifying setup..."
      echo ""
      echo "============================================="
      echo "  Directory contents:"
      echo "============================================="
      ldapsearch -x -H ldap://localhost -b "$LDAP_BASE_DN" -LLL "(objectClass=*)" dn
      echo ""
      echo "============================================="
      echo "  Setup complete!"
      echo "============================================="
      echo ""
      echo "  Admin DN:       cn=admin,$LDAP_BASE_DN"
      echo "  Admin password: $ADMIN_PASS"
      echo ""
      echo "  Users: alice (alice123), bob (bob123), charlie (charlie123)"
      echo "  Group: developers (alice, bob, charlie)"
      echo ""
      echo "  phpLDAPadmin: http://localhost:8080/phpldapadmin"
      echo "  (from host browser, login with admin DN above)"
      echo ""
      echo "  Try from the client VM:"
      echo "    ldapsearch -x -H ldap://192.168.100.1 -b \"$LDAP_BASE_DN\" \"(uid=alice)\""
      echo ""

  - path: /home/labuser/demo-cleanup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # demo-cleanup.sh — Remove all LDAP entries and reset to empty state
      set -euo pipefail

      LDAP_BASE_DN="dc=ldap-lab,dc=local"
      ADMIN_PASS="admin"

      echo "============================================="
      echo "  LDAP Demo Cleanup"
      echo "============================================="
      echo ""
      echo "  This will delete all entries under $LDAP_BASE_DN"
      echo "  and reconfigure slapd to its initial empty state."
      echo ""

      # Delete users
      echo "[1/3] Deleting users..."
      for uid in alice bob charlie; do
        ldapdelete -x -D "cn=admin,$LDAP_BASE_DN" -w "$ADMIN_PASS" \
          "uid=$uid,ou=users,$LDAP_BASE_DN" 2>/dev/null && \
          echo "  Deleted: uid=$uid" || echo "  Skip: uid=$uid (not found)"
      done
      echo ""

      # Delete group
      echo "[2/3] Deleting groups..."
      ldapdelete -x -D "cn=admin,$LDAP_BASE_DN" -w "$ADMIN_PASS" \
        "cn=developers,ou=groups,$LDAP_BASE_DN" 2>/dev/null && \
        echo "  Deleted: cn=developers" || echo "  Skip: cn=developers (not found)"
      echo ""

      # Delete OUs
      echo "[3/3] Deleting organizational units..."
      for ou in users groups; do
        ldapdelete -x -D "cn=admin,$LDAP_BASE_DN" -w "$ADMIN_PASS" \
          "ou=$ou,$LDAP_BASE_DN" 2>/dev/null && \
          echo "  Deleted: ou=$ou" || echo "  Skip: ou=$ou (not found)"
      done
      echo ""

      echo "============================================="
      echo "  Cleanup complete!"
      echo "============================================="
      echo ""
      echo "  The directory is now empty (only the base DN remains)."
      echo "  Run 'bash ~/demo-setup.sh' to recreate everything."
      echo ""

runcmd:
  - netplan apply
  - |
    # Configure phpLDAPadmin
    if [ -f /etc/phpldapadmin/config.php ]; then
      # Allow access from any host
      sed -i "s|\$servers->setValue('server','host','127.0.0.1');|\$servers->setValue('server','host','localhost');|" /etc/phpldapadmin/config.php
      # Set correct base DN and admin bind DN
      sed -i "s/dc=example,dc=com/dc=ldap-lab,dc=local/g" /etc/phpldapadmin/config.php
    fi
    if [ -f /etc/apache2/conf-available/phpldapadmin.conf ]; then
      sed -i 's/Require local/Require all granted/' /etc/apache2/conf-available/phpldapadmin.conf
    fi
    if [ -f /etc/apache2/conf-enabled/phpldapadmin.conf ]; then
      sed -i 's/Require local/Require all granted/' /etc/apache2/conf-enabled/phpldapadmin.conf
    fi
    # Fix phpLDAPadmin PHP 8.1 compatibility issues
    PLA_DIR="/usr/share/phpldapadmin/lib"
    # 1) Add E_DEPRECATED early return in custom error handler
    if [ -f "$PLA_DIR/functions.php" ]; then
      sed -i '/^function app_error_handler/a\\tif ($errno == E_DEPRECATED) return true;' "$PLA_DIR/functions.php"
    fi
    # 2) Fix password_hash() name collision with PHP built-in
    if [ -f "$PLA_DIR/TemplateRender.php" ]; then
      sed -i "s/password_hash/password_hash_custom/g" "$PLA_DIR/TemplateRender.php"
    fi
    # 3) Fix bogus "Memory Limit low" warning (string vs int comparison in PHP 8)
    if [ -f "$PLA_DIR/functions.php" ]; then
      sed -i "s/ini_get('memory_limit') > -1/rtrim(ini_get('memory_limit'),'M') > -1/" "$PLA_DIR/functions.php"
      sed -i "s/ini_get('memory_limit') < \$config/rtrim(ini_get('memory_limit'),'M') < \$config/" "$PLA_DIR/functions.php"
    fi
    # 4) Fix is_resource() for PHP 8.1 (ldap_connect returns object, not resource)
    if [ -f "$PLA_DIR/ds_ldap.php" ]; then
      sed -i 's/! is_resource(\$resource)/! (is_resource(\$resource) || is_object(\$resource))/' "$PLA_DIR/ds_ldap.php"
      sed -i 's/! is_resource(\$connect)/! (is_resource(\$connect) || is_object(\$connect))/' "$PLA_DIR/ds_ldap.php"
      sed -i 's/is_resource(\$search)/is_resource(\$search) || is_object(\$search)/g' "$PLA_DIR/ds_ldap.php"
    fi
    systemctl restart apache2 || true
  - chown labuser:labuser /home/labuser/demo-setup.sh /home/labuser/demo-cleanup.sh
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== ldap-lab-server VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-server"

cat > "$LAB_DIR/meta-data-server" <<METADATA
instance-id: ${SERVER_VM}-001
local-hostname: ${SERVER_VM}
METADATA

success "Created cloud-init for $SERVER_VM"

# --- LDAP Client VM cloud-init ---
info "Creating cloud-init for $CLIENT_VM..."
cat > "$LAB_DIR/user-data-client" <<'USERDATA'
#cloud-config
hostname: ldap-lab-client
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - ldap-utils
  - nano
  - net-tools
  - iputils-ping
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/netplan/60-internal.yaml
    content: |
      network:
        version: 2
        ethernets:
          ldaplan:
            match:
              macaddress: "52:54:00:00:04:02"
            addresses:
              - 192.168.100.2/24
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;31mldap-lab-client\033[0m — \033[1mLDAP Client Lab\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mRole:\033[0m  LDAP Client VM
        \033[1;33mStatic IP:\033[0m  \033[1;36m192.168.100.2\033[0m
        \033[1;33mLDAP Server:\033[0m  \033[1;36m192.168.100.1\033[0m

        \033[1;33mUseful commands:\033[0m
          \033[0;32mldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local"\033[0m
          \033[0;32mldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(uid=alice)"\033[0m
          \033[0;32mldapadd -x -D "cn=admin,dc=ldap-lab,dc=local" -W -H ldap://192.168.100.1 -f entry.ldif\033[0m
          \033[0;32mldapmodify -x -D "cn=admin,dc=ldap-lab,dc=local" -W -H ldap://192.168.100.1 -f modify.ldif\033[0m
          \033[0;32mldapdelete -x -D "cn=admin,dc=ldap-lab,dc=local" -W -H ldap://192.168.100.1 "dn_to_delete"\033[0m
          \033[0;32mping 192.168.100.1\033[0m

        \033[1;33mLDAP concepts:\033[0m
          DN    = Distinguished Name (unique path to an entry)
          Base  = Starting point for searches (e.g. dc=ldap-lab,dc=local)
          Scope = sub (all levels), one (one level), base (entry itself)

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m         type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m


runcmd:
  - netplan apply
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - echo "=== ldap-lab-client VM is ready! ==="
USERDATA

# Inject the SSH public key into user-data
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data-client"

cat > "$LAB_DIR/meta-data-client" <<METADATA
instance-id: ${CLIENT_VM}-001
local-hostname: ${CLIENT_VM}
METADATA

success "Created cloud-init for $CLIENT_VM"
echo ""

# =============================================
# Step 3: Generate cloud-init ISOs
# =============================================
info "Step 3: Cloud-init ISOs"
echo ""
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}

CIDATA_SERVER="$LAB_DIR/cidata-server.iso"
genisoimage -output "$CIDATA_SERVER" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-server" "meta-data=$LAB_DIR/meta-data-server" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_SERVER"

CIDATA_CLIENT="$LAB_DIR/cidata-client.iso"
genisoimage -output "$CIDATA_CLIENT" -volid cidata -joliet -rock \
    -graft-points "user-data=$LAB_DIR/user-data-client" "meta-data=$LAB_DIR/meta-data-client" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_CLIENT"
echo ""

# =============================================
# Step 4: Create overlay disks
# =============================================
info "Step 4: Overlay disks"
echo ""
echo "  Each VM gets its own overlay disk (copy-on-write) so the"
echo "  base cloud image is never modified."
echo ""

OVERLAY_SERVER="$LAB_DIR/${SERVER_VM}-disk.qcow2"
if [[ -f "$OVERLAY_SERVER" ]]; then rm -f "$OVERLAY_SERVER"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_SERVER" "${QLAB_DISK_SIZE:-}"

OVERLAY_CLIENT="$LAB_DIR/${CLIENT_VM}-disk.qcow2"
if [[ -f "$OVERLAY_CLIENT" ]]; then rm -f "$OVERLAY_CLIENT"; fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_CLIENT" "${QLAB_DISK_SIZE:-}"
echo ""

# =============================================
# Step 5: Start both VMs
# =============================================
info "Step 5: Starting VMs (internal LAN: 192.168.100.0/24)"
echo ""

# Multi-VM: resource check, cleanup trap, rollback on failure
MEMORY_TOTAL=$(( MEMORY * 2 ))
check_host_resources "$MEMORY_TOTAL" 2
declare -a STARTED_VMS=()
register_vm_cleanup STARTED_VMS

info "Starting $SERVER_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_SERVER" "$CIDATA_SERVER" "$MEMORY" "$SERVER_VM" auto \
    "hostfwd=tcp::0-:80" \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${SERVER_LAN_MAC}" || exit 1

echo ""

info "Starting $CLIENT_VM..."
start_vm_or_fail STARTED_VMS "$OVERLAY_CLIENT" "$CIDATA_CLIENT" "$MEMORY" "$CLIENT_VM" auto \
    "-netdev" "socket,id=vlan1,mcast=${INTERNAL_MCAST}" \
    "-device" "virtio-net-pci,netdev=vlan1,mac=${CLIENT_LAN_MAC}" || exit 1

# Successful start — disable cleanup trap
trap - EXIT

echo ""
echo "============================================="
echo "  ldap-lab: Both VMs are booting"
echo "============================================="
echo ""
echo "  LDAP Server VM:"
echo "    SSH:           qlab shell $SERVER_VM"
echo "    Log:           qlab log $SERVER_VM"
echo "    Static IP:     $SERVER_INTERNAL_IP"
echo "    phpLDAPadmin:  check port with 'qlab ports'"
echo ""
echo "  LDAP Client VM:"
echo "    SSH:           qlab shell $CLIENT_VM"
echo "    Log:           qlab log $CLIENT_VM"
echo "    Static IP:     $CLIENT_INTERNAL_IP"
echo ""
echo "  Internal LAN:   192.168.100.0/24"
echo "  Credentials:    labuser / labpass"
echo "  LDAP Admin DN:  cn=admin,$LDAP_BASE_DN"
echo ""
echo "  Wait ~90s for boot + package installation."
echo ""
echo "  Quick start:"
echo "    qlab shell $SERVER_VM"
echo "    bash ~/demo-setup.sh"
echo ""
echo "  Stop both VMs:"
echo "    qlab stop $PLUGIN_NAME"
echo ""
echo "  Stop a single VM:"
echo "    qlab stop $SERVER_VM"
echo "    qlab stop $CLIENT_VM"
echo ""
echo "  Tip: override resources with environment variables:"
echo "    QLAB_MEMORY=4096 QLAB_DISK_SIZE=30G qlab run ${PLUGIN_NAME}"
echo "============================================="
