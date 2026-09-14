---
kicker: QLab · ldap-lab
title: |
  A directory, and
  who is allowed to read it
subtitle: >
  OpenLDAP populated from empty, queried from another machine, and asked the
  same question twice — once anonymously and once authenticated — to show that
  the answer depends on who is asking. Captured from a running pair.
facts:
  - [Command, "`qlab run ldap-lab`"]
  - [VMs, "`ldap-lab-server` 192.168.100.1 · `ldap-lab-client` 192.168.100.2"]
  - [Directory, "`dc=ldap-lab,dc=local`"]
  - [Outcome, "`qlab test ldap-lab` → 6 exercises, 28 checks, all passed"]
---

## 1. Two machines, and an empty directory

{{evidence:topology}}

{{evidence:before as=shell}}

`slapd` is running, but `namingContexts` says `dc=nodomain` — the Debian default
for a package installed without being configured. There is a server and no
directory in it. Exercise 1 of the guide fixes that with a script:

{{evidence:setup as=shell}}

## 2. A directory is a tree, and the path is the name

{{evidence:tree}}

Every entry's name — its **distinguished name** — is its full path through the
tree, read from the leaf upwards. `uid=alice,ou=users,dc=ldap-lab,dc=local` is
both the identifier and the location; there is no separate key. Move an entry and
its name changes, which is why renaming in LDAP is a different operation from
editing.

The root here is `dc=ldap-lab,dc=local`, built from *domain components* — an
old convention that maps a DNS name onto a tree root. `ou` is an organisational
unit, which is nothing more than a container you chose to create.

## 3. An entry is a set of attributes, and its classes decide which

{{evidence:entry}}

Read the `objectClass` lines first, because they are the schema: they declare
what this entry *is*, and between them they decide which attributes are required
and which are merely allowed.

- `inetOrgPerson` brings the human fields — `cn`, `sn`, `givenName`, `mail`.
- `posixAccount` brings the Unix ones — `uidNumber`, `gidNumber`,
  `homeDirectory`, `loginShell`.

That second class is the whole reason LDAP is used for login: those are exactly
the fields `/etc/passwd` holds. A machine configured to consult this directory
gets its users from here instead of from a local file, and `alice` becomes the
same account everywhere.

Note also that an attribute may appear more than once — `objectClass` does here.
LDAP attributes are multi-valued by nature, which is unlike a database column.

{{evidence:group}}

Membership is `memberUid`, listed on the **group**, not on the users. So "which
groups is alice in" is a search across groups, not a field you read on alice.
That is the opposite of the intuition most people bring, and it is why
`memberOf` exists as an optional overlay that maintains the reverse pointer.

## 4. Filters

{{evidence:filters as=shell}}

LDAP filters are prefix notation: the operator comes first, then its operands,
each in its own parentheses. `(&(a)(b))` is AND, `(|(a)(b))` is OR, `(!(a))` is
NOT. It reads badly at first and composes well once you accept it.

`(uid=*)` is a presence test — entries that have the attribute at all,
regardless of value. It is also the cheapest useful filter for finding out what
kind of entries a directory contains.

## 5. Over the network, and who is asking

{{evidence:from-the-client as=shell}}

The same query from the other machine. Nothing is installed on the client beyond
`ldapsearch`; a directory is a network service, and this is the normal way to use
it.

{{evidence:bind as=shell}}

Now the point. Both queries ask for `userPassword` on the same entry:

- **anonymously**, the entry comes back with the dn and nothing else — the
  attribute was withheld, without an error;
- **bound as the directory manager**, the attribute is there.

That is LDAP access control working as intended, and the shape of it is worth
noticing: you are not told that something was hidden. An anonymous search that
returns fewer attributes than you expected is the normal signal that you should
have authenticated.

The value itself is base64 (`::` rather than `:` after the attribute name) and
inside it is `{SSHA}` — a salted hash, not the password.

{{evidence:teardown as=shell}}

## 6. Verification

{{evidence:qlab-test grep="Exercise [0-9]+:|Exercises |All exercises" as=shell}}

## 7. What to take away

- The distinguished name is the path. Identity and location are the same thing.
- `objectClass` is the schema: it decides which attributes an entry may and must
  have.
- `posixAccount` is what makes a directory usable for Unix login.
- Membership lives on the group as `memberUid`; the reverse view needs an overlay.
- Filters are prefix notation. `(uid=*)` tests presence.
- An anonymous bind is a real identity with real limits, and being denied an
  attribute looks like the attribute not existing.

`guide.md` in the plugin carries the exercises: configuring the domain by hand,
building the tree, adding users and groups, querying from the client,
phpLDAPadmin, and modifying entries.
