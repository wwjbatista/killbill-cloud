# Installation

1. Update your `ansible.cfg` with:

```
[defaults]
roles_path = ~/.ansible/roles/
library = ~/.ansible/roles/killbill-cloud/ansible/library
```

2. Create a file `requirements.yml`:

```
- src: https://github.com/killbill/killbill-cloud
```

then run `ansible-galaxy install -r requirements.yml`.

The roles can now be referenced in your playbooks via `killbill-cloud/ansible/roles/XXX` (e.g. `killbill-cloud/ansible/roles/kpm`).

See below for example playbooks.

# Usage

## killbill.yml playbook

Playbook to install Kill Bill (KPM is a pre-requisite):

```
ansible-playbook -i <HOST_FILE> killbill.yml
```

The playbook has several roles:

* common: Ansible setup (defines `ansible_ruby_interpreter`)
* tomcat: `$CATALINA_BASE` setup (does not install nor manage Tomcat itself)
* killbill: Kill Bill setup and installation

Configuration:

* [group_vars/all.yml](group_vars/all.yml) defines what to install (KPM version, Kill Bill version, plugins, etc.) and the main configuration options. This could be overridden in a child `group_vars` or even in `host_vars` (https://docs.ansible.com/ansible/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable)
* [templates/killbill/killbill.properties.j2](templates/killbill/killbill.properties.j2) is the main Kill Bill configuration file
* [templates/tomcat/conf/setenv.sh.j2](templates/tomcat/conf/setenv.sh.j2) defines JVM level system properties

## kpm.yml playbook

Example playbook on how to install KPM:

```
ansible-playbook -i <HOST_FILE> kpm.yml
```

## tomcat.yml playbook

Example playbook on how to install Tomcat (Java is a pre-requisite):

```
ansible-playbook -i <HOST_FILE> tomcat.yml
```

## plugin.yml playbook

Allow to restart a specific plugin

For example to restart `adyen` plugin
```
ansible-playbook -i <HOST_FILE> plugin.yml --extra-vars "plugin_key=adyen"
```

# Extending

To build upon these roles, you can create your own play, e.g.:

```
---
- name: Deploy Kill Bill
  hosts: all
  tasks:
    - name: setup Ruby
      include_role:
        name: killbill-cloud/ansible/roles/common
    - name: setup Tomcat conf files
      include_role:
        name: killbill-cloud/ansible/roles/tomcat
    - name: install Kill Bill
      include_role:
        name: killbill-cloud/ansible/roles/killbill
    - name: customize Kill Bill
      import_tasks: roles/acme/tasks/main.yml
```

Note that you need to have your own templates directory, containing your own templates.

# Internals

## killbill_facts module

```
# Assume KPM is installed through Rubygems
ansible <HOST_GROUP> -i <HOST_FILE> -m killbill_facts -a 'config_file=/path/to/kpm.yml'

# Self-contained KPM installed
ansible <HOST_GROUP> -i <HOST_FILE> -m killbill_facts -a 'config_file=/path/to/kpm.yml kpm_path=/path/to/kpm-0.5.2-linux-x86_64'

# Without kpm.yml
ansible <HOST_GROUP> -i <HOST_FILE> -m killbill_facts -a 'killbill_web_path=/path/to/apache-tomcat/webapps/ROOT bundles_dir=/var/tmp/bundles'
```

Ansible requires the module file to start with `/usr/bin/ruby` to allow for shebang line substitution. If no Ruby interpreter is available at that path, you can configure it through `ansible_ruby_interpreter`, which is set per-host as an inventory variable associated with a host or group of hosts (e.g. `ansible_ruby_interpreter=/opt/kpm-0.5.2-linux-x86_64/lib/ruby/bin/ruby` in your host file).
