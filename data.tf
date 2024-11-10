data "aws_caller_identity" "work1dev" {
    provider = aws.work1dev
}

data "aws_caller_identity" "work2dev" {
    provider = aws.work2dev
}

data "aws_caller_identity" "dev" {
    provider = aws.dev
}


data "aws_region" "work1dev" {
        provider = aws.dev

}

data "aws_region" "work2dev" {
        provider = aws.work2dev

}

data "aws_region" "dev" {
        provider = aws.dev

}

