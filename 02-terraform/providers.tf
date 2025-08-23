terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.0" 
    }
  }
}

provider "openstack" {
  #cloud = "devstack"  //Cloud.yaml을 사용하기때문에 주석 처리 => 사용하지않을 시 해당 섹션에 인증정보를 담으면됨
}
