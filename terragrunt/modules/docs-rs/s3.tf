resource "aws_s3_bucket" "storage" {
  bucket = "static-docs-rs"
}

resource "aws_s3_bucket_policy" "static_access" {
  bucket = aws_s3_bucket.storage.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowStaticDocsRsAccess",
        Effect = "Allow",
        Action = "s3:GetObject",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Resource = "${aws_s3_bucket.storage.arn}/*",
        Condition = {
          StringEquals = {
            "s3:ExistingObjectTag/static-cloudfront-access" = "allow"
          }
          StringLike = {
            "AWS:SourceArn" = "${aws_cloudfront_distribution.static.arn}"
          }
        }
      }
    ]
  })
}

// Store inventory CSV for later processing
resource "aws_s3_bucket_inventory" "storage" {
  count = var.inventories_bucket_arn == "" ? 0 : 1

  name    = "all-objects-csv"
  bucket  = aws_s3_bucket.storage.id
  enabled = true

  included_object_versions = "Current"
  optional_fields          = ["ETag", "ReplicationStatus", "Size"]

  schedule {
    frequency = "Weekly"
  }
  destination {
    bucket {
      bucket_arn = var.inventories_bucket_arn
      prefix     = aws_s3_bucket.storage.id
      format     = "CSV"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "backups" {
  bucket = "docs.rs-backups"
}

resource "aws_s3_bucket_acl" "backups" {
  bucket = aws_s3_bucket.backups.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id = "Expire database/ backups after 30 days"

    filter {
      prefix = "database/"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days                         = 30
      expired_object_delete_marker = false
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
