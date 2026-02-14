# ldap-lab — LDAP Directory Services Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)](https://github.com/manzolo/qlab)

A [QLab](https://github.com/manzolo/qlab) plugin that boots two virtual machines for practicing LDAP directory services with OpenLDAP, phpLDAPadmin, and ldap-utils.

## Architecture

```
    Internal LAN (192.168.100.0/24)
┌────────────────────────────────────────────┐
│                                            │
│  ┌─────────────────┐  ┌─────────────────┐  │
│  │ ldap-lab-server │  │ ldap-lab-client │  │
│  │ SSH: 2242       │  │ SSH: 2243       │  │
│  │ 192.168.100.1   │◄─│ 192.168.100.2   │  │
│  │ slapd + phpLDAP │  │ ldap-utils      │  │
│  │ admin :8080     │  │                 │  │
│  └─────────────────┘  └─────────────────┘  │
│                                            │
└────────────────────────────────────────────┘
```

## Objectives

- Understand LDAP concepts (DIT, DN, entries, attributes, objectClasses)
- Configure OpenLDAP (slapd) with a custom domain and base DN
- Create organizational units (OUs), users, and groups with LDIF files
- Query the directory with ldapsearch using filters and scopes
- Modify and delete entries with ldapmodify and ldapdelete
- Use phpLDAPadmin as a web-based directory browser

## How It Works

1. **Cloud image**: Downloads a minimal Ubuntu 22.04 cloud image (~250MB)
2. **Cloud-init**: Creates `user-data` for both VMs with LDAP packages
3. **ISO generation**: Packs cloud-init files into ISOs (cidata)
4. **Overlay disks**: Creates COW disks for each VM (original stays untouched)
5. **QEMU boot**: Starts both VMs with SSH access and a shared internal LAN

## Credentials

Both VMs use the same credentials:
- **Username:** `labuser`
- **Password:** `labpass`

LDAP admin (after running `demo-setup.sh`):
- **Admin DN:** `cn=admin,dc=ldap-lab,dc=local`
- **Password:** `admin`

## Network

| VM              | SSH (host) | Internal LAN IP        | Extra Ports          |
|-----------------|------------|------------------------|----------------------|
| ldap-lab-server | port 2242  | 192.168.100.1 (static) | 8080 (phpLDAPadmin)  |
| ldap-lab-client | port 2243  | 192.168.100.2 (static) | —                    |

The VMs are connected by a direct internal LAN (`192.168.100.0/24`) via QEMU socket networking.

## Usage

```bash
# Install the plugin
qlab install ldap-lab

# Run the lab (starts both VMs)
qlab run ldap-lab

# Wait ~90s for boot and package installation, then:

# Connect to the server VM
qlab shell ldap-lab-server

# Run the demo setup (creates domain, users, groups)
bash ~/demo-setup.sh

# Connect to the client VM
qlab shell ldap-lab-client

# Query the directory from the client
ldapsearch -x -H ldap://192.168.100.1 -b "dc=ldap-lab,dc=local"

# Access phpLDAPadmin from host browser
# http://localhost:8080/phpldapadmin

# Stop both VMs
qlab stop ldap-lab

# Stop a single VM
qlab stop ldap-lab-server
qlab stop ldap-lab-client
```

## Exercises

> **New to LDAP?** See the [Step-by-Step Guide](GUIDE.md) for complete walkthroughs with full config examples.

| # | Exercise | What you'll do |
|---|----------|----------------|
| 1 | **Quick start with demo** | Run demo-setup.sh on server, query from client |
| 2 | **Configure domain manually** | Use dpkg-reconfigure slapd to set up dc=ldap-lab,dc=local |
| 3 | **Create structure** | Build OUs (users, groups) with LDIF files and ldapadd |
| 4 | **Add users and groups** | Create user entries with passwords and group memberships |
| 5 | **Query from client** | Use ldapsearch with filters, base DN, and scopes |
| 6 | **phpLDAPadmin** | Browse and manage the directory via web interface |
| 7 | **Modify and delete** | Use ldapmodify and ldapdelete to change entries |
| 8 | **Reset and redo** | Clean up with demo-cleanup.sh and start over |

## Managing VMs

```bash
# View boot logs
qlab log ldap-lab-server
qlab log ldap-lab-client

# Check running VMs
qlab status
```

## Resetting

To start fresh, stop and re-run:

```bash
qlab stop ldap-lab
qlab run ldap-lab
```

Or reset the entire workspace:

```bash
qlab reset
```
