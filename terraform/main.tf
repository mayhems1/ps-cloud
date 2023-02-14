terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.49.0"
    }
  }
}

# Configure the PS Cloud Provider
provider "openstack" {
  user_name   = var.openstack_user_name
  tenant_name = var.openstack_tenant_name
  password    = var.openstack_password
  auth_url    = var.openstack_auth_url
  region      = var.openstack_region
}

# Import Public key
resource "openstack_compute_keypair_v2" "gerhard-cloud-key" {
  name       = "gerhard-key"
  public_key = var.openstack_public_key
}

# Create Network
resource "openstack_networking_network_v2" "private_network" {
  name             = "network_local"
  admin_state_up   = "true"
}

resource "openstack_networking_subnet_v2" "private_subnet" {
  name             = "subnet_name"
  network_id       = openstack_networking_network_v2.private_network.id
  cidr             = "192.168.100.0/24"
  dns_nameservers  = [
                      "8.8.8.8",
                      "1.1.1.1"
                     ]
  ip_version       = 4
  enable_dhcp      = true
  depends_on = [openstack_networking_network_v2.private_network]
}

resource "openstack_networking_floatingip_v2" "instance_fip" {
  pool             = "FloatingIP Net"
}

# Security
resource "openstack_compute_secgroup_v2" "security_group" {
  name             = "sg_name"
  description      = "open all icmp, and ssh"
  rule {
    from_port      = 22
    to_port        = 22
    ip_protocol    = "tcp"
    cidr           = "0.0.0.0/0"
       }
  rule {
    from_port      = 80
    to_port        = 80
    ip_protocol    = "tcp"
    cidr           = "0.0.0.0/0"
       }
  rule {
    from_port      = -1
    to_port        = -1
    ip_protocol    = "icmp"
    cidr           = "0.0.0.0/0"
       }
} 
# Create Router
resource "openstack_networking_router_v2" "router" {
  name             = "router_name"
  external_network_id = "83554642-6df5-4c7a-bf55-21bc74496109" #UUID of the floating ip network
  admin_state_up   = "true"
  depends_on = [openstack_networking_network_v2.private_network]
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id        = openstack_networking_router_v2.router.id
  subnet_id        = openstack_networking_subnet_v2.private_subnet.id
  depends_on       = [openstack_networking_router_v2.router]
}

# Create disk and VMs

# Apache servers
resource "openstack_blockstorage_volume_v3" "apache_volume" {
  count       = var.openstack_apache_instance_count
  name        = format("%s-%s-%02d", "volume", var.openstack_apache_instance_instance_name, count.index)
  description  = "apache instance volume"
  volume_type = "ceph-hdd"
  size        = 4
  image_id    = var.openstack_image_id
  enable_online_resize = "true"
}

resource "openstack_compute_instance_v2" "apache_instance" {
  count            = var.openstack_apache_instance_count
  name             = format("%s-%02d", var.openstack_apache_instance_instance_name, count.index)
  flavor_name      = "d1.ram2cpu1"
  key_pair         = openstack_compute_keypair_v2.gerhard-cloud-key.name
  user_data = <<-EOF
                #cloud-config
                password: ${var.openstack_instance_password}
                chpasswd: { expire: False }
                ssh_pwauth: True                
              EOF
  security_groups  = [openstack_compute_secgroup_v2.security_group.name]
  depends_on = [ 
    openstack_networking_network_v2.private_network,
    openstack_blockstorage_volume_v3.apache_volume
    ]
  network {
    uuid           = openstack_networking_network_v2.private_network.id
    fixed_ip_v4    = "192.168.100.3${count.index}"
  }

  block_device {
    uuid           = openstack_blockstorage_volume_v3.apache_volume[count.index].id
    boot_index     = 0
    source_type    = "volume"
    destination_type = "volume"
    delete_on_termination = true
  }
}

# HAproxy servers
resource "openstack_blockstorage_volume_v3" "haproxy_volume" {
  count       = var.openstack_haproxy_instance_count
  name        = format("%s-%s-%02d", "volume", var.openstack_haproxy_instance_instance_name, count.index)
  description  = "haproxy instance volume"
  volume_type = "ceph-hdd"
  size        = 4
  image_id    = var.openstack_image_id
  enable_online_resize = "true"
}

resource "openstack_compute_instance_v2" "haproxy_instance" {
  count            = var.openstack_haproxy_instance_count
  name             = format("%s-%02d", var.openstack_haproxy_instance_instance_name, count.index)
  flavor_name      = "d1.ram2cpu1"
  key_pair         = openstack_compute_keypair_v2.gerhard-cloud-key.name
  user_data = <<-EOF
                #cloud-config
                password: ${var.openstack_instance_password}
                chpasswd: { expire: False }
                ssh_pwauth: True                
              EOF
  security_groups  = [openstack_compute_secgroup_v2.security_group.name]
  depends_on = [ 
    openstack_networking_network_v2.private_network
    # openstack_blockstorage_volume_v3.vmcontrol_volume
    ]
  network {
    uuid           = openstack_networking_network_v2.private_network.id
    fixed_ip_v4    = "192.168.100.2${count.index}"
  }

  block_device {
    uuid           = openstack_blockstorage_volume_v3.haproxy_volume[count.index].id
    boot_index     = 0
    source_type    = "volume"
    destination_type = "volume"
    delete_on_termination = true
  }

}

# Floating IP
resource "openstack_compute_floatingip_associate_v2" "instance_fip_association" {
  count            = var.openstack_haproxy_instance_count
  floating_ip      = openstack_networking_floatingip_v2.instance_fip.address
  instance_id      = openstack_compute_instance_v2.haproxy_instance[count.index].id
  fixed_ip         = openstack_compute_instance_v2.haproxy_instance[count.index].access_ip_v4
}

# VM-control
resource "openstack_blockstorage_volume_v3" "vmcontrol_volume" {
  count       = var.openstack_vmcontrol_instance_count
  name        = format("%s-%s-%02d", "volume", var.openstack_vmcontrol_instance_instance_name, count.index)
  description  = "vmcontrol instance volume"
  volume_type = "ceph-hdd"
  size        = 4
  image_id    = var.openstack_image_id
  enable_online_resize = "true"
}

resource "openstack_compute_instance_v2" "vmcontrol_instance" {
  count            = var.openstack_vmcontrol_instance_count
  name             = format("%s-%02d", var.openstack_vmcontrol_instance_instance_name, count.index)
  flavor_name      = "d1.ram2cpu1"
  key_pair         = openstack_compute_keypair_v2.gerhard-cloud-key.name
  user_data = <<-EOF
                #cloud-config
                password: ${var.openstack_instance_password}
                chpasswd: { expire: False }
                ssh_pwauth: True                
              EOF
  security_groups  = [openstack_compute_secgroup_v2.security_group.name]
  depends_on = [ 
    openstack_networking_network_v2.private_network,
    openstack_blockstorage_volume_v3.vmcontrol_volume,
    openstack_compute_instance_v2.haproxy_instance
    ]
  network {
    uuid           = openstack_networking_network_v2.private_network.id
    fixed_ip_v4    = "192.168.100.1${count.index}"
  }
  block_device {
    uuid           = openstack_blockstorage_volume_v3.vmcontrol_volume[count.index].id
    boot_index     = 0
    source_type    = "volume"
    destination_type = "volume"
    delete_on_termination = true
  }
}

# Apply Ansible
resource "null_resource" "ansible_playbook" {
  depends_on = [
    openstack_compute_instance_v2.apache_instance,
    openstack_compute_instance_v2.haproxy_instance,
    openstack_compute_instance_v2.vmcontrol_instance
    ]
# Ansible inventory file generate
  provisioner "file" {
    destination = "/tmp/hosts"
    content     = <<-EOT
    [haproxy]
    %{ for ip in openstack_compute_instance_v2.haproxy_instance.*.network.0.fixed_ip_v4 }${ip}
    %{ endfor }
    [apache]
    %{ for ip in openstack_compute_instance_v2.apache_instance.*.network.0.fixed_ip_v4 }${ip}
    %{ endfor }
    EOT
  }
  provisioner "file" {
    source      = "~/.ssh/ps-test/id_rsa"
    destination = "/home/centos/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y epel-release",
      "sudo yum install -y ansible",
      "sudo wget ${var.openstack_ansible_role_url} -P /home/centos/",
      "sudo tar -zxvf /home/centos/ansible.tar.gz",
      "sudo cp /home/centos/ansible/ansible.cfg /home/centos/.ansible.cfg",
      "sudo cp /tmp/hosts /home/centos/ansible/inventory/hosts",
      "sudo chmod 600 /home/centos/.ssh/id_rsa",
      "sudo chown centos:centos /home/centos/.ssh/id_rsa",
      "sudo chown centos:centos /home/centos/ansible/inventory/hosts",
      "ansible-playbook -i /home/centos/ansible/inventory/hosts /home/centos/ansible/apache_playbook.yml",
      "ansible-playbook -i /home/centos/ansible/inventory/hosts /home/centos/ansible/haproxy_playbook.yml"
    ]
  }
  
  connection {
    type           = "ssh"
    user           = "centos"
    bastion_host   = openstack_networking_floatingip_v2.instance_fip.address
    host           = openstack_compute_instance_v2.vmcontrol_instance.0.access_ip_v4
    private_key    = file("~/.ssh/ps-test/id_rsa")
    timeout        = "20m"
  }
}


# Show useful info
output "ip_of_instances" {
  description = "Persistent Private node information"
  depends_on = [ openstack_compute_instance_v2.haproxy_instance, openstack_compute_instance_v2.apache_instance ]
  value = {
    "haproxy_names"     = [ "${openstack_compute_instance_v2.haproxy_instance.*.name}" ]
    "haproxy_ips"       = [ "${openstack_compute_instance_v2.haproxy_instance.*.network.0.fixed_ip_v4}" ]
    "apache_names"     = [ "${openstack_compute_instance_v2.apache_instance.*.name}" ]
    "apache_ips"       = [ "${openstack_compute_instance_v2.apache_instance.*.network.0.fixed_ip_v4}" ]
  }
}

output "floating_ip_is" {
  value = "${openstack_networking_floatingip_v2.instance_fip.address}"
}
