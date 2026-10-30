# S3 do diagrama: bucket privado, versionado e criptografado.

resource "aws_s3_bucket" "dados" {
  bucket = "${var.projeto}-dados-${data.aws_caller_identity.atual.account_id}"
  tags   = { Name = "${var.projeto}-dados" }
}

resource "aws_s3_bucket_public_access_block" "dados" {
  bucket                  = aws_s3_bucket.dados.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "dados" {
  bucket = aws_s3_bucket.dados.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dados" {
  bucket = aws_s3_bucket.dados.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "dados" {
  bucket = aws_s3_bucket.dados.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
