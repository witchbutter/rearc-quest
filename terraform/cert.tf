data "aws_route53_zone" "quest" {
  name = local.dns_domain
}

resource "aws_acm_certificate" "wildcardcert" {
  domain_name               = "quest.${local.dns_domain}"
  validation_method         = "DNS"
  subject_alternative_names = [join(".", ["*", "quest.${local.dns_domain}"])]

  tags = {
    Owner = "witchbutter"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "wildcardvalidate" {
  for_each = {
    for dvo in aws_acm_certificate.wildcardcert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = data.aws_route53_zone.quest.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "wildcardvalidate" {
  certificate_arn         = aws_acm_certificate.wildcardcert.arn
  validation_record_fqdns = [for record in aws_route53_record.wildcardvalidate : record.fqdn]
}
