# Fail on errors.
set -x

# Elevate priviledges, retaining the environment.
sudo -E su

# Install dev tools and Ansible 2.2
yum install -y "@Development Tools" python2-pip openssl-devel python-devel gcc libffi-devel
pip install -Iv ansible==2.2.0.0

# Clone the openshift-ansible repo, which contains the installer.
git clone https://github.com/openshift/openshift-ansible
cd openshift-ansible

# Create our Ansible inventory:
mkdir -p /etc/ansible
cat > /etc/ansible/hosts <<- EOF
# Create an OSEv3 group that contains the masters and nodes groups
[OSEv3:children]
masters
nodes

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
# SSH user, this user should allow ssh based auth without requiring a password
ansible_ssh_user=ec2-user

# If ansible_ssh_user is not root, ansible_become must be set to true
ansible_become=true

deployment_type=origin

# uncomment the following to enable htpasswd authentication; defaults to DenyAllPasswordIdentityProvider
# openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/origin/master/htpasswd'}]

# Create the masters host group. Be explicit with the openshift_hostname,
# otherwise it will resolve to something like ip-10-0-1-98.ec2.internal and use
# that as the node name.
[masters]
master.openshift.local openshift_hostname=master.openshift.local

# host group for etcd
[etcd]
master.openshift.local

# host group for nodes, includes region info
[nodes]
master.openshift.local openshift_node_labels="{'region': 'infra', 'zone': 'default'}" openshift_schedulable=true
node1.openshift.local openshift_hostname=node1.openshift.local openshift_node_labels="{'region': 'primary', 'zone': 'east'}"
node2.openshift.local openshift_hostname=node2.openshift.local openshift_node_labels="{'region': 'primary', 'zone': 'west'}"
EOF

# Run the playbook.
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/byo/config.yml

ansible-playbook playbooks/adhoc/uninstall.yml
