{{- $specName          := .Data.Provider.SpecName }}
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

{{- if .Data.CloudflareSubscription }}
resource "cloudflare_load_balancer_pool" "lb_pool_{{ $resourceSuffix }}" {
  provider  = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
  account_id = "{{ .Data.Provider.GetCloudflare.GetAccountID }}"
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
}

resource "cloudflare_load_balancer_monitor" "monitor_{{ $resourceSuffix }}" {
  provider    = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
  account_id  = "{{ .Data.Provider.GetCloudflare.GetAccountID }}"
  type        = "tcp"
  port        = 6443
  timeout     = 5
  retries     = 2
  interval    = 60
}

resource "cloudflare_load_balancer" "load_balancer_{{ $resourceSuffix }}" {
  provider    = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
  zone_id = data.cloudflare_zone.cloudflare_zone_{{ $resourceSuffix }}.id
  name    = "{{ $.Data.Hostname }}.{{ .Data.DNSZone }}"
  fallback_pool_id = cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id

  default_pool_ids = [
    cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id,
  ]
  ttl     = 30

  steering_policy="random"
}
{{- else }}
{{- range $ip := .Data.RecordData.IP }}

  {{- $escapedIPv4 := replaceAll $ip.V4 "." "_"}}
  {{- $recordResourceName := printf "record_%s_%s" $escapedIPv4 $resourceSuffix }}

  resource "cloudflare_record" "{{ $recordResourceName }}" {
    provider = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
    zone_id  = data.cloudflare_zone.cloudflare_zone_{{ $resourceSuffix }}.id
    name     = "{{ $.Data.Hostname }}"
    value    = "{{ $ip.V4 }}"
    type     = "A"
    ttl      = 300
  }
{{- end }}
{{- end }}

{{- $clusterID := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}
output "{{ $clusterID }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  value = { "{{ .Data.ClusterName }}-{{ .Data.ClusterHash }}-endpoint" = format("%s.%s", "{{ .Data.Hostname }}", "{{ .Data.DNSZone }}")}
}
