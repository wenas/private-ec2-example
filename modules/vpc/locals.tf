locals {
   
    cidr_block = "10.0.0.0/16"
    public_subnet_cidr_blocks = ["10.0.0.0/24", "10.0.1.0/24"]
    private_subnet_cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24"]
    availability_zones = ["ap-northeast-1a", "ap-northeast-1c"]


}
