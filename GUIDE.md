# LDAP Lab — Step-by-Step Guide

This guide walks you through understanding and configuring LDAP directory services from scratch using the two lab VMs.

## Prerequisites

Start the lab and wait for both VMs to finish booting (~90 seconds):

```bash
qlab run ldap-lab
```

Open **two terminals** and connect to each VM:

```bash
# Terminal 1 — Server
qlab shell ldap-lab-server

# Terminal 2 — Client
qlab shell ldap-lab-client
```

On each VM, make sure cloud-init has finished:

```bash
cloud-init status --wait
```

## Network Topology

Each VM has **two network interfaces**:

- **eth0** (SLIRP): for SSH access from the host (`qlab shell`)
- **Internal LAN**: a direct virtual link between the VMs (`192.168.100.0/24`)

```
        Host Machine
       ┌────────────┐
       │  SSH :auto  │──────► ldap-lab-server
       │  SSH :auto  │──────► ldap-lab-client
       │  Web :auto  │──────► phpLDAPadmin
       └────────────┘

   Internal LAN (192.168.100.0/24)
  ┌──────────────────────────────────┐
  │                                  │
  │  ┌─────────────┐   ┌─────────────┐
  │  │ ldap-server │   │ ldap-client │
  │  │ 192.168.    │   │ 192.168.    │
  │  │   100.1     │◄──│   100.2     │
  │  │ slapd +     │   │ ldap-utils  │
  │  │ phpLDAPadmin│   │             │
  │  └─────────────┘   └─────────────┘
  └──────────────────────────────────┘
```

The server runs OpenLDAP (slapd) and phpLDAPadmin. The client has ldap-utils for querying and modifying the directory. The server starts with slapd in an unconfigured state — you set up the domain yourself.

---

## Exercise 1: Quick Start with Demo Script

The fastest way to see LDAP in action. The demo script configures the domain, creates OUs, users, and a group automatically.

### 1.1 Run the demo setup on the server

On **ldap-lab-server**:

```bash
bash ~/demo-setup.sh
```

This will:
- Configure slapd with domain `dc=ldap-lab,dc=local`
- Create OUs: `users` and `groups`
- Create 3 users: `alice`, `bob`, `charlie`
- Create a group: `developers` (with all 3 users)

Note the admin password: `admin`

### 1.2 Query from the client

On **ldap-lab-client**:

```bash
# List all entries
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" -LLL

# Find a specific user
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(uid=alice)" -LLL

# List all users
ldapsearch -x -H ldap://192.168.100.1 -b "ou=users,dc=ldap-lab,dc=local" -LLL

# Find the developers group
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(cn=developers)" -LLL
```

### 1.3 Test connectivity

```bash
ping 192.168.100.1
```

---

## Exercise 2: Configure the LDAP Domain Manually

If you want to understand the configuration process instead of using the demo script, start with a clean state.

### 2.1 Reset (if demo was already run)

On **ldap-lab-server**:

```bash
bash ~/demo-cleanup.sh
```

Or for a full reset, stop and re-run the lab:

```bash
# On host
qlab stop ldap-lab
qlab run ldap-lab
```

### 2.2 Reconfigure slapd

On **ldap-lab-server**:

```bash
sudo dpkg-reconfigure slapd
```

Answer the prompts:
1. **Omit OpenLDAP server configuration?** → **No**
2. **DNS domain name:** → `ldap-lab.local`
3. **Organization name:** → `LDAP Lab`
4. **Administrator password:** → `admin` (and confirm)
5. **Database backend:** → **MDB**
6. **Remove database when slapd is purged?** → **No**
7. **Move old database?** → **Yes**

### 2.3 Verify the configuration

```bash
# Check the base DN was created
ldapsearch -x -H ldap://localhost -b "dc=ldap-lab,dc=local" -LLL

# You should see:
# dn: dc=ldap-lab,dc=local
# objectClass: top
# objectClass: dcObject
# objectClass: organization
# o: LDAP Lab
# dc: ldap-lab
```

### 2.4 Check slapd is running

```bash
sudo systemctl status slapd
```

---

## Exercise 3: Create the Directory Structure (OUs)

Organizational Units (OUs) are containers that organize entries in the directory tree (DIT — Directory Information Tree).

### 3.1 Create an LDIF file for OUs

On **ldap-lab-server**, create the file:

```bash
nano ~/ous.ldif
```

Content:

```ldif
dn: ou=users,dc=ldap-lab,dc=local
objectClass: organizationalUnit
ou: users

dn: ou=groups,dc=ldap-lab,dc=local
objectClass: organizationalUnit
ou: groups
```

### 3.2 Add the OUs to the directory

```bash
ldapadd -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin -f ~/ous.ldif
```

You should see:

```
adding new entry "ou=users,dc=ldap-lab,dc=local"
adding new entry "ou=groups,dc=ldap-lab,dc=local"
```

### 3.3 Verify

```bash
ldapsearch -x -H ldap://localhost -b "dc=ldap-lab,dc=local" -LLL "(objectClass=organizationalUnit)"
```

---

## Exercise 4: Add Users and Groups

### 4.1 Create a user LDIF file

On **ldap-lab-server**:

```bash
nano ~/users.ldif
```

Content:

```ldif
dn: uid=alice,ou=users,dc=ldap-lab,dc=local
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
mail: alice@ldap-lab.local

dn: uid=bob,ou=users,dc=ldap-lab,dc=local
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
mail: bob@ldap-lab.local
```

### 4.2 Generate password hashes and add them

Generate a password hash:

```bash
slappasswd -s alice123
```

Copy the output (e.g. `{SSHA}...`) and add a `userPassword` line to each user in the LDIF file. Or add the users first without passwords, then set passwords with ldapmodify.

### 4.3 Add the users

```bash
ldapadd -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin -f ~/users.ldif
```

### 4.4 Set passwords with ldapmodify

If you didn't include passwords in the LDIF:

```bash
ALICE_PASS=$(slappasswd -s alice123)

ldapmodify -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin <<EOF
dn: uid=alice,ou=users,dc=ldap-lab,dc=local
changetype: modify
add: userPassword
userPassword: $ALICE_PASS
EOF
```

### 4.5 Create a group

```bash
nano ~/group.ldif
```

Content:

```ldif
dn: cn=developers,ou=groups,dc=ldap-lab,dc=local
objectClass: posixGroup
cn: developers
gidNumber: 10000
memberUid: alice
memberUid: bob
```

```bash
ldapadd -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin -f ~/group.ldif
```

### 4.6 Verify

```bash
# List all users
ldapsearch -x -H ldap://localhost -b "ou=users,dc=ldap-lab,dc=local" -LLL

# Show the group and its members
ldapsearch -x -H ldap://localhost -b "dc=ldap-lab,dc=local" "(cn=developers)" -LLL
```

---

## Exercise 5: Query from the Client

### 5.1 Basic search

On **ldap-lab-client**:

```bash
# All entries under the base DN
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" -LLL
```

### 5.2 Search with filters

```bash
# Find user by uid
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(uid=alice)" -LLL

# Find all posixAccount entries
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(objectClass=posixAccount)" -LLL

# Find users with uid starting with 'a'
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(uid=a*)" -LLL

# AND filter: posixAccount AND uid=alice
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(&(objectClass=posixAccount)(uid=alice))" -LLL

# OR filter: uid=alice OR uid=bob
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(|(uid=alice)(uid=bob))" -LLL
```

### 5.3 Search scopes

```bash
# sub (default) — search entire subtree
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" -s sub -LLL "(uid=*)"

# one — search only one level below the base
ldapsearch -x -H ldap://192.168.100.1 -b "ou=users,dc=ldap-lab,dc=local" -s one -LLL

# base — return only the base entry itself
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" -s base -LLL
```

### 5.4 Select specific attributes

```bash
# Only show cn and mail for all users
ldapsearch -x -H ldap://192.168.100.1 -b "ou=users,dc=ldap-lab,dc=local" -LLL cn mail

# Show uid and homeDirectory
ldapsearch -x -H ldap://192.168.100.1 -b "ou=users,dc=ldap-lab,dc=local" -LLL "(uid=alice)" uid homeDirectory mail
```

### 5.5 Authenticated search (as admin)

```bash
# Some attributes (like userPassword) require authentication
ldapsearch -x -H ldap://192.168.100.1 -D "cn=admin,dc=ldap-lab,dc=local" -w admin \
  -b "ou=users,dc=ldap-lab,dc=local" -LLL "(uid=alice)"
```

---

## Exercise 6: phpLDAPadmin (Web Interface)

### 6.1 Access phpLDAPadmin

Run `qlab ports` on the host to find the phpLDAPadmin port, then open your browser:

```
http://localhost:<port>/phpldapadmin
```

### 6.2 Login

Click **login** on the left panel and use:

- **Login DN:** `cn=admin,dc=ldap-lab,dc=local`
- **Password:** `admin` (or whatever you set during configuration)

### 6.3 Browse the directory

After logging in, you can:

- Expand the tree on the left to see the DIT structure
- Click on entries to view their attributes
- Use the **Search** feature to find entries
- Create new entries using templates (OU, user, group)

### 6.4 Create a new user via phpLDAPadmin

1. Click on `ou=users` in the tree
2. Click **Create a child entry**
3. Select **Generic: User Account**
4. Fill in the form and click **Create Object**

### 6.5 Verify from the command line

After creating entries via phpLDAPadmin, verify from the client:

```bash
ldapsearch -x -H ldap://192.168.100.1 -b "ou=users,dc=ldap-lab,dc=local" -LLL
```

---

## Exercise 7: Modify and Delete Entries

### 7.1 Modify an attribute

On **ldap-lab-server** (or client with `-H ldap://192.168.100.1`):

```bash
ldapmodify -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin <<EOF
dn: uid=alice,ou=users,dc=ldap-lab,dc=local
changetype: modify
replace: mail
mail: alice.smith@ldap-lab.local
EOF
```

### 7.2 Add a new attribute

```bash
ldapmodify -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin <<EOF
dn: uid=alice,ou=users,dc=ldap-lab,dc=local
changetype: modify
add: telephoneNumber
telephoneNumber: +1-555-0101
EOF
```

### 7.3 Delete an attribute

```bash
ldapmodify -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin <<EOF
dn: uid=alice,ou=users,dc=ldap-lab,dc=local
changetype: modify
delete: telephoneNumber
EOF
```

### 7.4 Add a member to a group

```bash
ldapmodify -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin <<EOF
dn: cn=developers,ou=groups,dc=ldap-lab,dc=local
changetype: modify
add: memberUid
memberUid: newuser
EOF
```

### 7.5 Delete an entry

```bash
# Delete a single user
ldapdelete -x -D "cn=admin,dc=ldap-lab,dc=local" -w admin "uid=bob,ou=users,dc=ldap-lab,dc=local"

# Verify
ldapsearch -x -H ldap://localhost -b "ou=users,dc=ldap-lab,dc=local" -LLL "(uid=bob)"
```

Note: You cannot delete an OU that still contains entries. Delete all children first.

### 7.6 Verify changes from the client

On **ldap-lab-client**:

```bash
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local" "(uid=alice)" -LLL mail telephoneNumber
```

---

## Exercise 8: Cleanup and Start Over

### 8.1 Use the cleanup script

On **ldap-lab-server**:

```bash
bash ~/demo-cleanup.sh
```

This removes all users, groups, and OUs, leaving only the base DN.

### 8.2 Verify empty state

```bash
ldapsearch -x -H ldap://localhost -b "dc=ldap-lab,dc=local" -LLL
```

You should see only the base entry (`dc=ldap-lab,dc=local`).

### 8.3 Rebuild from scratch

Now you can either:
- Run `bash ~/demo-setup.sh` to recreate everything automatically
- Follow Exercises 2-4 to do it manually step by step

### 8.4 Full VM reset

For a completely fresh start:

```bash
# On host
qlab stop ldap-lab
qlab run ldap-lab
```

---

## Troubleshooting

### slapd won't start

Check the logs:

```bash
sudo journalctl -u slapd -n 50 --no-pager
```

Common causes:
- slapd was never configured (run `sudo dpkg-reconfigure slapd`)
- Configuration errors in the database

Verify slapd status:

```bash
sudo systemctl status slapd
```

### ldapadd/ldapsearch fails with "No such object"

The base DN doesn't exist. Make sure you've configured slapd with the correct domain first:

```bash
sudo dpkg-reconfigure slapd
```

### ldapadd fails with "Already exists"

The entry you're trying to add already exists. Use `ldapmodify` to change it, or delete it first with `ldapdelete`.

### Can't connect from client

1. Verify the server is running: `sudo systemctl status slapd`
2. Check network connectivity: `ping 192.168.100.1`
3. Verify slapd is listening: `sudo ss -tlnp | grep 389`
4. Try from the server first: `ldapsearch -x -H ldap://localhost -b "dc=ldap-lab,dc=local"`

### phpLDAPadmin shows blank page or error

1. Check Apache is running: `sudo systemctl status apache2`
2. Check Apache error log: `sudo tail /var/log/apache2/error.log`
3. Restart Apache: `sudo systemctl restart apache2`

### "Invalid credentials" error

Make sure you're using the correct admin DN and password:
- DN: `cn=admin,dc=ldap-lab,dc=local`
- Password: whatever you set during `dpkg-reconfigure slapd` (default in demo: `admin`)

### General: packages not installed

If commands like `slapd` or `ldapsearch` are not found, cloud-init may still be running:

```bash
cloud-init status --wait
```
