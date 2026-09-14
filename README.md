# ldap-lab — OpenLDAP Directory Lab

[![QLab Plugin](https://img.shields.io/badge/QLab-Plugin-blue)](https://github.com/manzolo/qlab)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Walkthrough](https://img.shields.io/badge/walkthrough-EN%20%26%20IT-informational)](docs/walkthrough-en.pdf)

A two-VM [QLab](https://github.com/manzolo/qlab) lab on a private LAN — an OpenLDAP server
with phpLDAPadmin, and a client with `ldap-utils` — for building a directory tree from
LDIF and querying it, by hand and through the web.

## Quick start

```bash
qlab install ldap-lab
qlab run ldap-lab             # boots 2 VMs (~90s)
qlab shell ldap-lab-server    # slapd + phpLDAPadmin — labuser / labpass
qlab shell ldap-lab-client    # ldapsearch / ldapadd — labuser / labpass
qlab test ldap-lab            # run the automated checks
qlab stop ldap-lab
```

`demo-setup.sh` on the server seeds a ready-made tree if you want to skip straight to querying.

## What's inside

| # | Exercise | What you do |
|---|----------|-------------|
| 1 | Quick start with demo | `demo-setup.sh` on the server, query from the client |
| 2 | Configure the domain | `dpkg-reconfigure slapd` for `dc=ldap-lab,dc=local` |
| 3 | Create structure | OUs (users, groups) via LDIF and `ldapadd` |
| 4 | Users & groups | user entries with passwords, group membership |
| 5 | Query from the client | `ldapsearch` with filters, base DN, scopes |
| 6 | phpLDAPadmin | browse and manage the directory in the browser |

## Network

Private LAN `192.168.100.0/24`, isolated between the two VMs.

| VM | Address | Role |
|----|---------|------|
| `ldap-lab-server` | `192.168.100.1` | slapd + phpLDAPadmin |
| `ldap-lab-client` | `192.168.100.2` | ldap-utils |

**LDAP admin** (after `demo-setup.sh`): `cn=admin,dc=ldap-lab,dc=local` / `admin`.
SSH: `labuser` / `labpass`. phpLDAPadmin and SSH are forwarded to the host — see `qlab ports`.

## Learn more

- 📖 **[Step-by-step guide](guide.md)** — every exercise with full LDIF and commands
- 📄 **Illustrated walkthrough** — a real run, captured live: **[English](docs/walkthrough-en.pdf)** · **[Italiano](docs/walkthrough-it.pdf)**
- 🧩 **[QLab](https://github.com/manzolo/qlab)** — the plugin runner: how install, overlays and cloud-init work
