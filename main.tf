#Below is for the converted DynamoDB table

resource "aws_dynamodb_table" "resume_table" {
  name           = "terraformed_cloudresume_test"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"  # String type to match your Lambda function
  }
}

# Add initial counter item
resource "aws_dynamodb_table_item" "counter" {
  table_name = aws_dynamodb_table.resume_table.name
  hash_key   = aws_dynamodb_table.resume_table.hash_key

  item = jsonencode({
    "id"    = {"S": "1"}
    "views" = {"N": "0"}
  })
}




#Below is for the converted lambda function

data "archive_file" "zip" {
  type = "zip"
  source_dir = "${path.module}/lambda/"
  output_path = "${path.module}/packedlambda.zip"
}

resource "aws_lambda_function" "myfunc" {
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  function_name    = "myfunc"
  role            = aws_iam_role.iam_for_lambda.arn
  handler         = "func.lambda_handler"
  runtime         = "python3.8"
  
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}



resource "aws_iam_policy" "iam_policy_for_resume_project" {
  name        = "aws_iam_policy_for_terraform_resume_project"
  path        = "/"
  description = "AWS IAM Policy for managing the resume project role"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
        Effect   = "Allow"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/terraformed_cloudresume_test"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_resume_project.arn
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_full_access" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function_url" "url1" {
  function_name = aws_lambda_function.myfunc.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins = [
      "https://resume.jackieweng.com",
      "https://jackieweng.com",
      "https://www.jackieweng.com"
    ]
    allow_methods = ["GET"]
    allow_headers = ["content-type"]
    max_age = 86400
  }
}



#Below is for the main website and its S3 bucket#

# Create an S3 bucket for hosting the static website
resource "aws_s3_bucket" "website_bucket" {
    bucket = var.bucket_name
}
# Define the bucket policy to control access to the S3 bucket
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  # Reference the ID of the bucket we created above
  bucket = aws_s3_bucket.website_bucket.id
   # Create an IAM policy document using jsonencode function
  policy = jsonencode({
    # Specify the policy version
    Version = "2012-10-17"
    Statement = [
      {
        # Allow GetObject action (downloading/reading files)
        Action    = "s3:GetObject"
        # Allow the action specified above
        Effect    = "Allow"
        # Apply to all objects in the bucket using wildcard
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
        # Specify who can access (CloudFront Origin Access Identity)
        Principal = {
          CanonicalUser = aws_cloudfront_origin_access_identity.origin_access_identity.s3_canonical_user_id
        }
      }
    ]
  })
}

# Upload the index.html file to the S3 bucket
resource "aws_s3_object" "index_html" {
   # Specify which bucket to upload to
  bucket = aws_s3_bucket.website_bucket.id
  # Set the name/path of the file in the bucket
  key = "index.html"
  # Specify the local file to upload
  source = "website/index.html"
  # Add MD5 hash for change detection
  etag = filemd5("website/index.html")
  # Set the correct content type for HTML files
  content_type = "text/html"
}

resource "aws_s3_object" "projects_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key = "projects.html"
  source = "website/projects.html"
  etag = filemd5("website/projects.html")
  content_type = "text/html"
}

resource "aws_s3_object" "bytesizebits_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key = "bytesizebits.html"
  source = "website/bytesizebits.html"
  etag = filemd5("website/bytesizebits.html")
  content_type = "text/html"
}

resource "aws_s3_object" "bytesize-article-1_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key = "bytesize-article-1.html"
  source = "website/bytesize-article-1.html"
  etag = filemd5("website/bytesize-article-1.html")
  content_type = "text/html"
}

resource "aws_s3_object" "aws-resume-retrospective_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key = "aws-resume-retrospective.html"
  source = "website/aws-resume-retrospective.html"
  etag = filemd5("website/aws-resume-retrospective.html")
  content_type = "text/html"
}

# For all images in the images folder
resource "aws_s3_object" "images" {
  for_each = fileset("website/images", "*.{jpg,png}")
  bucket = aws_s3_bucket.website_bucket.id
  key = "images/${each.value}"
  source = "website/images/${each.value}"
  etag = filemd5("website/images/${each.value}")
  content_type = endswith(each.value, ".jpg") ? "image/jpeg" : "image/png"
}

# CSS files
resource "aws_s3_object" "css_files" {
  for_each = fileset("website/assets/css", "*.css")
  bucket = aws_s3_bucket.website_bucket.id
  key = "assets/css/${each.value}"
  source = "website/assets/css/${each.value}"
  etag = filemd5("website/assets/css/${each.value}")
  content_type = "text/css"
}

# JavaScript files
resource "aws_s3_object" "js_files" {
  for_each = fileset("website/assets/js", "*.js")
  bucket = aws_s3_bucket.website_bucket.id
  key = "assets/js/${each.value}"
  source = "website/assets/js/${each.value}"
  etag = filemd5("website/assets/js/${each.value}")
  content_type = "application/javascript"
}

# Webfonts files
resource "aws_s3_object" "webfonts" {
  for_each = fileset("website/assets/webfonts", "*.*")
  bucket = aws_s3_bucket.website_bucket.id
  key = "assets/webfonts/${each.value}"
  source = "website/assets/webfonts/${each.value}"
  etag = filemd5("website/assets/webfonts/${each.value}")
  content_type = "application/octet-stream"
}

# SASS files in base directory
resource "aws_s3_object" "sass_base" {
  for_each = fileset("website/assets/sass/base", "*.scss")
  bucket = aws_s3_bucket.website_bucket.id
  key = "assets/sass/base/${each.value}"
  source = "website/assets/sass/base/${each.value}"
  etag = filemd5("website/assets/sass/base/${each.value}")
  content_type = "text/x-scss"
}

# SASS files in components directory
resource "aws_s3_object" "sass_components" {
  for_each = fileset("website/assets/sass/components", "*.scss")
  bucket = aws_s3_bucket.website_bucket.id
  key = "assets/sass/components/${each.value}"
  source = "website/assets/sass/components/${each.value}"
  etag = filemd5("website/assets/sass/components/${each.value}")
  content_type = "text/x-scss"
}

# SASS files in layout directory
resource "aws_s3_object" "sass_layout" {
  for_each = fileset("website/assets/sass/layout", "*.scss")
  bucket = aws_s3_bucket.website_bucket.id
  key = "assets/sass/layout/${each.value}"
  source = "website/assets/sass/layout/${each.value}"
  etag = filemd5("website/assets/sass/layout/${each.value}")
  content_type = "text/x-scss"
}

# SASS files in libs directory
resource "aws_s3_object" "sass_libs" {
  for_each = fileset("website/assets/sass/libs", "*.scss")
  bucket = aws_s3_bucket.website_bucket.id
  key = "assets/sass/libs/${each.value}"
  source = "website/assets/sass/libs/${each.value}"
  etag = filemd5("website/assets/sass/libs/${each.value}")
  content_type = "text/x-scss"
}



#Below is for the Cloudfront IaC#

# Create a CloudFront Origin Access Identity to securely access S3 content
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Origin Access Identity for static website"
}

# Configure the CloudFront distribution
resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  # Define the origin (S3 bucket) configuration
  origin {
    # Use the S3 bucket's regional domain name
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    # Unique identifier for this origin
    origin_id = var.bucket_name

    # Configure S3 specific settings with OAI
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  # Enable the distribution and IPv6
  enabled = true
  is_ipv6_enabled = true
  # Set the default page (e.g., index.html)
  default_root_object = var.website_index_document

   # Configure caching behavior and security settings
  default_cache_behavior {
    # Define allowed HTTP methods
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    # Specify which methods to cache
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.bucket_name
    
    # Configure request forwarding
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Force HTTPS for all requests
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

   # Configure SSL/TLS certificate settings
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Set geographic restrictions (none in this case)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Add tags for resource management
  tags = {
    Name = "Cloudfront Distribution"
    Environment = "Dev"
  }

  # Configure custom domain names
  aliases = [
    "jackieweng.com",
    "resume.jackieweng.com",
    "www.jackieweng.com"
  ]
  }


# Below is for creating the certificate validation records via ACM #

provider "aws" {
  alias  = "acm"
  region = "us-east-1"
  }

# Add ACM certificate (must be in us-east-1 region for CloudFront)
resource "aws_acm_certificate" "cert" {
  provider = aws.acm  # Add this provider block
  domain_name = "jackieweng.com"
  subject_alternative_names = ["*.jackieweng.com"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "primary" {
  name = "jackieweng.com."  # Note the trailing dot
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id  # I'll need to reference my Route53 zone
}
