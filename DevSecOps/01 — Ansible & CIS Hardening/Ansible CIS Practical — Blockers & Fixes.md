---
tags: [airnav-cadet, ansible, cis, troubleshooting, exam]
module: Ansible & CIS Hardening
status: complete
---

# Ansible CIS Practical — Blockers & Fixes

These are the list of blockers I encountered during the practical:

### Problem 1: AlmaLinux9 not giving the ansible user I created sudo access despite being specified during the install

FIX: log in using root, then add ansible user to the 'wheel' group to give them sudo access

```bash
usermod -aG wheel ansible
```


### Problem 2: After VM creation 'ansible all -m ping', encountered an error/ did not pong

FIX: typo in the inventory/hosts.yml  ansible_user was instead asnible_user

### Problem 3:  Faliure during pre-auditing, missing authselect profile

FIX: In group_vars/all/vars.yml, I created a custom profile for authselect since that was the recommendation in the error

```bash
rhel9cis_authselect_custom_profile_name: terminated_si_hans
```


### Problem 4: Successful & Completed CIS hardening but GNOME and GDM were removed in the process

FIX: In group_vars/all/vars.yml, this section of code
```bash 
# scope, level 1 only
rhel9cis_level_1: true
rhel9cis_level_2: false
```
	These do NOT disable level 2 tasks, they only disable level 2 goss audits, the primary way to fix is by disabling the level 2 tasks by hand (?).
