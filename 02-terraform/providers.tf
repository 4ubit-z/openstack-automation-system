terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.0" 
    }
  }
}

provider "openstack" {
  cloud = "devstack"
}
