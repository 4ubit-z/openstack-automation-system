# 인스턴스 관련
variable "instance_name" {
  description = "인스턴스 이름"
  default     = "tf-instance"
}

variable "image_id" {
  description = "이미지 UUID"
  default     = "d714507c-3a35-4020-ac27-c58fa93ac4f3"
}

variable "flavor_name" {
  description = "사용할 flavor"
  default     = "m1.medium"
}

variable "key_name" {
  description = "SSH key pair 이름"
  default     = "mykey"
}

variable "volume_size" {
  description = "루트 볼륨 크기 (GiB)"
  default     = 60
}

# 네트워크 관련
variable "network_name" {
  description = "내부 네트워크 이름"
  default     = "shared"
}

variable "subnet_name" {
  description = "내부 서브넷 이름"
  default     = "shared-subnet"
}
