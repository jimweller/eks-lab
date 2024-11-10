provider "aws" {
  alias  = "dev"
  region = "us-west-2"
  profile = "tf-dev/AWSAdministratorAccess"  # This is the base profile or root account that has permission to assume roles
}

provider "aws" {
  alias  = "work1dev"
  region = "us-west-2"
}

provider "aws" {
  alias  = "work2dev"
  region = "us-west-2"
}
