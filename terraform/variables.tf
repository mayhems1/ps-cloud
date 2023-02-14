variable "openstack_user_name" {
    default = ""
    type = string
}
variable "openstack_tenant_name" {
    default = ""
    type = string
}

variable "openstack_password" {
    default = ""
    type = string
}

variable "openstack_auth_url" {
    default = "https://auth.pscloud.io/v3/"
    type = string
    description = "OpenStack API URL"
}

variable "openstack_region" {
    default = "kz-ala-1"
    type = string
}

variable "openstack_public_key" {
    type = string
    default = ""
    description = "SSH key for a PS Cloud project"
}

variable "pub_key" {
    default = ""
}

variable "openstack_image_id" {
    type = string
    default = ""
}

variable "openstack_apache_instance_count" {
    type = number
    default = "1"
}

variable "openstack_apache_instance_instance_name" {
    type = string
    default = "apache-srv"
}

variable "openstack_vmcontrol_instance_count" {
    type = number
    default = "1"
}

variable "openstack_vmcontrol_instance_instance_name" {
    type = string
    default = "vmcontrol-srv"
}

variable "openstack_haproxy_instance_count" {
    type = number
    default = "1"
}

variable "openstack_haproxy_instance_instance_name" {
    type = string
    default = "haproxy-srv"
}

variable "openstack_ansible_role_url" {
    type = string
    default = ""  
}

variable "openstack_instance_password" {
    type = string
    default = ""  
}
