{{- $specName          := .Data.Provider.SpecName }}
{{- $protocol          := .Data.Role.Protocol }}
{{- $port              := .Data.Role.Port }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}

provider "cloudflare" {
  api_token = "${file("{{ $specName }}")}"
  alias = "cloudflare_dns_{{ $resourceSuffix }}"
}

data "cloudflare_zone" "cloudflare_zone_{{ $resourceSuffix }}" {
  provider   = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
  name       = "{{ .Data.DNSZone }}"
}

resource "cloudflare_load_balancer_pool" "lb_pool_{{ $resourceSuffix }}" {
  account_id = "{{ .Data.Provider.GetCloudflare.GetAccountID }}"
  provider  = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
  name      = "pool-{{ $resourceSuffix }}"

{{- range $ip := .Data.RecordData.IP }}
  {{- $ip_hash := (sha1sum $ip.V4 | trunc 8) }}
    origins {
      name    = "origin-{{ $ip_hash }}"
      address = "{{ $ip.V4 }}"
      weight  = 1
    }
  {{- end }}
  
  monitor = cloudflare_load_balancer_monitor.monitor_{{ $resourceSuffix }}.id

  origin_steering {
    policy = "random"
  }
}

resource "cloudflare_load_balancer_monitor" "monitor_{{ $resourceSuffix }}" {
  provider    = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
  account_id  = "{{ .Data.Provider.GetCloudflare.GetAccountID }}"
  type        = "{{ $protocol }}"
  port        = {{ $port }}
  timeout     = 5
  retries     = 2
  interval    = 60
}


resource "cloudflare_load_balancer" "load_balancer_{{ $resourceSuffix }}" {
  zone_id = data.cloudflare_zone.cloudflare_zone_{{ $resourceSuffix }}.id
  name    = "{{ $.Data.Hostname }}.{{ .Data.DNSZone }}"
  fallback_pool_id = cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id

  default_pool_ids = [
    cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id,
  ]
  ttl     = 30
}

{{- $clusterID := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}
output "{{ $clusterID }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  value = { "{{ .Data.ClusterName }}-{{ .Data.ClusterHash }}-endpoint" = format("%s.%s", "{{ .Data.Hostname }}", "{{ .Data.DNSZone }}")}
}
