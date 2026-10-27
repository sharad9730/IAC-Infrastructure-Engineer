instances = {
  "web-server" = {
    instance_type = "t3.micro"
    volume_type   = "gp3"
    volume_size   = 20
    key_name      = "key-web"
    environment   = "dev"
    owner         = "alice"
    ami           = "ami-1234567890abcdef0"
  },
  "db-server" = {
    instance_type = "m5.large"
    volume_type   = "io2" # Meets the io1/io2 requirement
    volume_size   = 100
    key_name      = "key-db"
    environment   = "prod"
    owner         = "bob"
    ami           = "ami-1234567890abcdef0"
  },
  "cache-server" = {
    instance_type = "t3.small"
    volume_type   = "gp2"
    volume_size   = 30
    key_name      = "key-cache"
    environment   = "stage"
    owner         = "charlie"
    ami           = "ami-1234567890abcdef0"
  },
  "worker-node" = {
    instance_type = "c5.large"
    volume_type   = "gp3"
    volume_size   = 50
    key_name      = "key-worker"
    environment   = "prod"
    owner         = "dave"
    ami           = "ami-1234567890abcdef0"
  },
  "bastion" = {
    instance_type = "t2.micro"
    volume_type   = "standard"
    volume_size   = 8
    key_name      = "key-bastion"
    environment   = "mgmt"
    owner         = "eve"
    ami           = "ami-1234567890abcdef0"
  }
}
