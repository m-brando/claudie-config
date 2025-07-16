{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}
{{- $clusterID         := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}
{{- $zoneName          := .Data.DNSZone }}

provider "cloudflare" {
  api_token = "${file("{{ $specName }}")}"
  alias = "cloudflare_dns_{{ $resourceSuffix }}"
}

data "cloudflare_zone" "cloudflare_zone_{{ $resourceSuffix }}" {
  provider   = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
  name       = "{{ .Data.DNSZone }}"
}

### If subscription has paid addon Cloudflare Load Balancing,
### implement load balancer with health check, otherwise
### create A records without load balancer and health check
{{- if hasExtension .Data "ProviderExtrasExtension" }}
{{- if .Data.ProviderExtrasExtension.SubscriptionAllowsHA }}
  resource "cloudflare_load_balancer_pool" "lb_pool_{{ $resourceSuffix }}" {
    provider    = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
    account_id  = "{{ .Data.Provider.GetCloudflare.GetAccountID }}"
    name        = "pool-{{ $resourceSuffix }}"

    {{- range $index, $ip := .Data.RecordData.IP }}
      origins {
        name    = "origin-{{ $index }}"
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
    provider          = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
    zone_id           = data.cloudflare_zone.cloudflare_zone_{{ $resourceSuffix }}.id
    name              = "{{ $.Data.Hostname }}.{{ .Data.DNSZone }}"
    fallback_pool_id  = cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id

    default_pool_ids = [
      cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id,
    ]
    ttl     = 30

    steering_policy="random"
  }
  ### If the input manifest includes alternativeNames,
  ### create additional load balancers using those names.
  ### These LBs will use the same pool as the primary domain.
  {{- if hasExtension .Data "AlternativeNamesExtension" }}
    {{- range $_, $alternativeName := .Data.AlternativeNamesExtension.Names }}
      {{- $recordResourceName := printf "record_%s_%s" $alternativeName $resourceSuffix }}

      resource "cloudflare_load_balancer" "load_balancer_{{ $recordResourceName }}" {
        provider    = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
        zone_id     = data.cloudflare_zone.cloudflare_zone_{{ $resourceSuffix }}.id
        name        = "{{ $alternativeName }}.{{ $.Data.DNSZone }}"
        fallback_pool_id = cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id

        default_pool_ids = [
          cloudflare_load_balancer_pool.lb_pool_{{ $resourceSuffix }}.id,
        ]
        ttl     = 30

        steering_policy="random"
      }
    output "{{ $clusterID }}_{{ $alternativeName }}_{{ $resourceSuffix }}" {
      value = { "{{ $clusterID }}-{{ $alternativeName }}-endpoint" = format("%s.%s", "{{ $alternativeName }}", "{{ $.Data.DNSZone }}")}
    }
    {{- end }}
  {{- end }}
  output "{{ $clusterID }}_{{ $resourceSuffix }}" {
    value = { "{{ $clusterID }}-endpoint" = format("%s.%s", "{{ .Data.Hostname }}", "{{ .Data.DNSZone }}")}
  }
### If subscription does not include claudflare paied addon
### for DNS balancing, create DNS A records with no health check
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
  {{- if hasExtension .Data "AlternativeNamesExtension" }}
	  {{- range $_, $alternativeName := .Data.AlternativeNamesExtension.Names }}
      {{- range $ip := $.Data.RecordData.IP }}
        {{- $escapedIPv4 := replaceAll $ip.V4 "." "_" }}
        {{- $recordResourceName := printf "record_%s_%s_%s" $alternativeName $escapedIPv4 $resourceSuffix }}

        resource "cloudflare_record" "{{ $recordResourceName }}" {
          provider = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
          zone_id = data.cloudflare_zone.cloudflare_zone_{{ $resourceSuffix }}.id
          name = "{{ $alternativeName }}"
          value = "{{ $ip.V4 }}"
          type = "A"
          ttl = 300
        }
      {{- end }}

    output "{{ $clusterID }}_{{ $alternativeName }}_{{ $resourceSuffix }}" {
      value = { "{{ $clusterID }}-{{ $alternativeName }}-endpoint" = format("%s.%s", "{{ $alternativeName }}", "{{ $.Data.DNSZone }}")}
    }
	  {{- end }}
  
  output "{{ $clusterID }}_{{ $resourceSuffix }}" {
    value = { "{{ $clusterID }}-endpoint" = format("%s.%s", "{{ .Data.Hostname }}", "{{ .Data.DNSZone }}")}
  }
  {{- end }}
{{- end }}
