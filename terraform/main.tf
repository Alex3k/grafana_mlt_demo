terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "1.34.0"
    }
  }
}

provider "google" {
  credentials = file(var.gcp_svc_acc_file_path)

  project = var.gcp_project_id
}

data "google_client_config" "provider" {}

resource "google_container_cluster" "cluster" {
  name               = "${var.owner_name}-mltdemo"
  location           = var.gcp_region
  initial_node_count = 1
  resource_labels = {
    owner = var.owner_name
  }
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {

  }
  node_config {
    preemptible  = false
    machine_type = "e2-standard-2"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      owner = var.owner_name
    }
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.cluster.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.cluster.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.cluster.endpoint}"
    token                  = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.cluster.master_auth.0.cluster_ca_certificate)
  }
}

provider "grafana" {
  alias         = "cloud"
  cloud_api_key = var.grafana_cloud_api_key
}

resource "grafana_cloud_stack" "stack" {
  provider = grafana.cloud

  name        = var.stack_slug
  slug        = var.stack_slug
  region_slug = var.grafana_stack_region_slug
}

resource "grafana_api_key" "management" {
  provider = grafana.cloud

  cloud_stack_slug = grafana_cloud_stack.stack.slug
  name             = "mlt-demo-api-key"
  role             = "Admin"
}

resource "grafana_cloud_plugin_installation" "flowchart" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.stack.slug
  slug       = "agenty-flowcharting-panel"
  version    = "0.9.1"
}

resource "grafana_cloud_api_key" "metrics_publish" {
  provider       = grafana.cloud
  name           = "MetricsPublisherForMLTDemo"
  role           = "MetricsPublisher"
  cloud_org_slug = grafana_cloud_stack.stack.org_slug
}

resource "grafana_synthetic_monitoring_installation" "stack" {
  provider              = grafana.cloud
  stack_id              = grafana_cloud_stack.stack.id
  metrics_instance_id   = grafana_cloud_stack.stack.prometheus_user_id
  logs_instance_id      = grafana_cloud_stack.stack.logs_user_id
  metrics_publisher_key = grafana_cloud_api_key.metrics_publish.key
}

provider "grafana" {
  alias           = "stack"
  sm_access_token = grafana_synthetic_monitoring_installation.stack.sm_access_token
  url             = grafana_cloud_stack.stack.url
  auth            = grafana_api_key.management.key
  sm_url          = var.synthetic_monitoring_api_url
}

resource "grafana_synthetic_monitoring_probe" "private_k8s_probe" {
  provider  = grafana.stack
  name      = "Private Probe"
  latitude  = 27.98606
  longitude = 86.92262
  region    = var.gcp_region
  labels = {
    type = "private"
  }
}

resource "helm_release" "grafana_agents" {
  chart = "../helm/grafana_agent"
  name  = "mlt-grafana-agent"

  set {
    name  = "tempo.username"
    value = grafana_cloud_stack.stack.traces_user_id
  }

  set {
    name  = "tempo.apikey"
    value = grafana_cloud_api_key.metrics_publish.key
  }

  set {
    name  = "tempo.url"
    value = "${regex("https://(tempo-.+.net)", grafana_cloud_stack.stack.traces_url)[0]}:443" # This returns an array, so getting the first element of that 

  }

  set {
    name  = "prometheus.username"
    value = grafana_cloud_stack.stack.prometheus_user_id
  }

  set {
    name  = "prometheus.apikey"
    value = grafana_cloud_api_key.metrics_publish.key
  }

  set {
    name  = "prometheus.url"
    value = grafana_cloud_stack.stack.prometheus_remote_write_endpoint
  }

  set {
    name  = "loki.username"
    value = grafana_cloud_stack.stack.logs_user_id
  }

  set {
    name  = "loki.apikey"
    value = grafana_cloud_api_key.metrics_publish.key
  }

  set {
    name  = "loki.url"
    value = grafana_cloud_stack.stack.logs_url
  }
}

resource "helm_release" "kube-state-metrics" {
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-state-metrics"
  name  = "ksm"
}


resource "helm_release" "k6" {
  chart = "../helm/k6"
  name  = "k6"

  set {
    name  = "prometheus.username"
    value = grafana_cloud_stack.stack.prometheus_user_id
  }

  set {
    name  = "prometheus.apikey"
    value = grafana_cloud_api_key.metrics_publish.key
  }

  set {
    name  = "prometheus.url"
    value = grafana_cloud_stack.stack.prometheus_remote_write_endpoint
  }
}

resource "kubernetes_deployment" "synthetic_monitoring_private_probe" {
  metadata {
    name = "synthetic-monitoring-private-probe"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        name = "synthetic-monitoring-private-probe"
      }
    }

    template {
      metadata {
        labels = {
          name = "synthetic-monitoring-private-probe"
        }
      }

      spec {
        container {
          image = "grafana/synthetic-monitoring-agent:v0.9.1-0-gc790779"
          name  = "synthetic-monitoring-private-probe"
          args = [
            "-verbose",
            "-api-server-address=synthetic-monitoring-grpc.grafana.net:443",
            "-api-token=${grafana_synthetic_monitoring_probe.private_k8s_probe.auth_token}"
          ]

          liveness_probe {
            http_get {
              path = "/"
              port = 4050
            }
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 4050
            }
          }

          port {
            container_port = 4050
            name           = "http-metrics"
          }

        }
      }
    }
  }
}


resource "grafana_synthetic_monitoring_check" "ecommerce_api_gateway" {
  provider = grafana.stack
  job      = "ecommerce-api-gateway"
  target   = "http://api-gateway.default.svc.cluster.local/"
  enabled  = false
  probes = [
    grafana_synthetic_monitoring_probe.private_k8s_probe.id
  ]
  labels = {
  }
  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = false
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes = [
        200
      ]

    }
  }
}


resource "grafana_synthetic_monitoring_check" "ecommerce_web_gateway" {
  provider = grafana.stack
  job      = "ecommerce-web-gateway"
  target   = "http://web-gateway.default.svc.cluster.local/"
  enabled  = false
  probes = [
    grafana_synthetic_monitoring_probe.private_k8s_probe.id
  ]
  labels = {
  }
  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = false
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes = [
        200
      ]

    }
  }
}

resource "grafana_synthetic_monitoring_check" "ecommerce_product" {
  provider = grafana.stack
  job      = "ecommerce-product"
  target   = "http://product.default.svc.cluster.local/"
  enabled  = false
  probes = [
    grafana_synthetic_monitoring_probe.private_k8s_probe.id
  ]
  labels = {
  }
  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = false
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes = [
        200
      ]

    }
  }
}

resource "grafana_synthetic_monitoring_check" "ecommerce_cart" {
  provider = grafana.stack
  job      = "ecommerce-cart"
  target   = "http://cart.default.svc.cluster.local/"
  enabled  = false
  probes = [
    grafana_synthetic_monitoring_probe.private_k8s_probe.id
  ]
  labels = {
  }
  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = false
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes = [
        200
      ]

    }
  }
}


resource "grafana_synthetic_monitoring_check" "ecommerce_checkout" {
  provider = grafana.stack
  job      = "ecommerce-checkout"
  target   = "http://checkout.default.svc.cluster.local/"
  enabled  = false
  probes = [
    grafana_synthetic_monitoring_probe.private_k8s_probe.id
  ]
  labels = {
  }
  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = false
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes = [
        200
      ]

    }
  }
}

resource "grafana_synthetic_monitoring_check" "ecommerce_content" {
  provider = grafana.stack
  job      = "ecommerce-content"
  target   = "http://content.default.svc.cluster.local/"
  enabled  = false
  probes = [
    grafana_synthetic_monitoring_probe.private_k8s_probe.id
  ]
  labels = {
  }
  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = false
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes = [
        200
      ]

    }
  }
}

resource "grafana_synthetic_monitoring_check" "ecommerce_payment" {
  provider = grafana.stack
  job      = "ecommerce-payment"
  target   = "http://payment.default.svc.cluster.local/"
  enabled  = false
  probes = [
    grafana_synthetic_monitoring_probe.private_k8s_probe.id
  ]
  labels = {
  }
  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = false
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
      valid_status_codes = [
        200
      ]

    }
  }
}

resource "grafana_folder" "ecommerce_app" {
  provider = grafana.stack
  title    = "Ecommerce App"
}


resource "grafana_data_source" "testdata" {
  provider            = grafana.stack
  type                = "testdata"
  name                = "testdata"
}

resource "grafana_data_source" "custom_tempo" {
  provider            = grafana.stack
  type                = "tempo"
  name                = "MLT Tempo"
  url                 = "${grafana_cloud_stack.stack.traces_url}/tempo"
  basic_auth_enabled  = true
  basic_auth_username = grafana_cloud_stack.stack.traces_user_id

  json_data_encoded = jsonencode({
    "nodeGraph" = {
      "enabled" : true
    }
    "tracesToLogs" = {
      "datasourceUid"      = "grafanacloud-logs"
      "filterByTraceID"    = false
      "mapTagNamesEnabled" = true
      "mappedTags" : [
        { "key" = "service.name", "value" = "container" }
      ]
      "spanEndTimeShift"   = "100ms"
      "spanStartTimeShift" = "-100ms"
    }
  })

  secure_json_data_encoded = jsonencode({
    "basicAuthPassword"   = var.grafana_cloud_api_key
    "basic_auth_password" = var.grafana_cloud_api_key
  })
}

resource "grafana_data_source" "custom_loki" {
  provider            = grafana.stack
  type                = "loki"
  name                = "MLT Logs"
  url                 = "${grafana_cloud_stack.stack.logs_url}"
  basic_auth_enabled  = true
  basic_auth_username = grafana_cloud_stack.stack.logs_user_id

  json_data_encoded = jsonencode({
    "derivedFields":[{
        "datasourceUid": grafana_data_source.custom_tempo.uid
        "matcherRegex":"traceID=(\\w+)",
        "name":"traceID",
        "url":"$${__value.raw}"
    }],
    "timeout":"300"
  })

  secure_json_data_encoded = jsonencode({
    "basicAuthPassword"   = var.grafana_cloud_api_key
    "basic_auth_password" = var.grafana_cloud_api_key
  })
}

resource "grafana_data_source" "custom_prometheus" {
  provider            = grafana.stack
  type                = "prometheus"
  name                = "MLT Metrics"
  url                 = "${grafana_cloud_stack.stack.prometheus_url}/api/prom"
  basic_auth_enabled  = true
  basic_auth_username = grafana_cloud_stack.stack.prometheus_user_id

  json_data_encoded = jsonencode({
    "exemplarTraceIdDestinations":[{
        "datasourceUid": grafana_data_source.custom_tempo.uid
        "name":"traceID",
    }],
    "timeout":"150",
    "timeInterval":"60s"
  })

  secure_json_data_encoded = jsonencode({
    "basicAuthPassword"   = var.grafana_cloud_api_key
    "basic_auth_password" = var.grafana_cloud_api_key
  })
}

resource "grafana_cloud_plugin_installation" "servicenow" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.stack.slug
  slug       = "grafana-servicenow-datasource"
  version    = "2.6.0"
}

resource "grafana_data_source" "servicenow" {
  provider            = grafana.stack
  type                = "grafana-servicenow-datasource"
  name                = "Servicenow"
  url                 = var.servicenow_url
  basic_auth_enabled  = true
  basic_auth_username = var.servicenow_username

  secure_json_data_encoded = jsonencode({
    "basicAuthPassword"   = var.servicenow_password
    "basic_auth_password" = var.servicenow_password
  })

    depends_on = [
    grafana_cloud_plugin_installation.servicenow
  ]
}

variable "contact_point_high_latency_body" {
  type    = string
  default = <<EOH
    {{ range .Alerts }} 
     <{{ .DashboardURL }}?var-services={{ .Labels.service_name }}|{{ .Labels.service_name }}>
    > SLO: *{{ .Annotations.SLO }}* _(95th percentile)_
    > SLI: *{{ .Annotations.Value }}* _(95th percentile)_
    > Investigate: <{{ .DashboardURL }}?var-services={{ .Labels.service_name }}|Service Overview>
    {{ end }}
EOH
}


variable "contact_point_too_many_connections_body" {
  type    = string
  default = <<EOH
    {{ range .Alerts }} 
    > Container: {{ .Annotations.container}}
    > Investigate: <{{ .DashboardURL }}?orgId=1&refresh=10s&from=now-5m&to=now|Service Overview>
    {{ end }}  
EOH
}

resource "grafana_contact_point" "default_slack" {
  provider = grafana.stack
  name     = "Default Slack"

  slack {
    recipient               = var.slack_channel_name
    token                   = var.slack_bot_token
    username                = "Grafana MLT Alerter"
    title                   = "{{ .CommonLabels.alertname }}"
    text                    = "Something went bang"
    disable_resolve_message = true
  }
}

resource "grafana_contact_point" "high_latency" {
  provider = grafana.stack
  name     = "Slack Latency"

  slack {
    recipient               = var.slack_channel_name
    token                   = var.slack_bot_token
    username                = "Grafana MLT Alerter"
    title                   = "{{ .CommonLabels.alertname }}"
    text                    = var.contact_point_too_many_connections_body
    disable_resolve_message = true
  }
}


resource "grafana_contact_point" "too_many_connections" {
  provider = grafana.stack
  name     = "Slack Too Many Pg Connections"

  slack {
    recipient               = var.slack_channel_name
    token                   = var.slack_bot_token
    username                = "Grafana MLT Alerter"
    title                   = "{{ .CommonLabels.alertname }}"
    text                    = var.contact_point_high_latency_body
    disable_resolve_message = true
  }
}

resource "grafana_contact_point" "servicenow" {
  provider = grafana.stack
  name     = "ServiceNow"

  webhook {
    url = var.servicenow_url
    http_method = "POST"
    basic_auth_user = var.servicenow_username
    basic_auth_password = var.servicenow_password
  }
}

resource "grafana_notification_policy" "notification_policy" {
  group_by      = ["alertname"]
  contact_point = grafana_contact_point.grafana_contact_point.name

  group_wait      = "45s"
  group_interval  = "6m"
  repeat_interval = "3h"

  policy {
    group_by = ["alert"]
    matcher {
      label = "itsm"
      match = "="
      value = "servicenow"
    }
    contact_point = grafana_contact_point.servicenow.name
    continue      = false
  }

  policy {
    group_by = ["alertname"]
    matcher {
      label = "alertname"
      match = "="
      value = "Too Many Open Postgres Clients"
    }
    contact_point = grafana_contact_point.too_many_connections.name
    continue      = false

    group_wait      = "2s"
    group_interval  = "2s"
    repeat_interval = "5m"
  }

  policy {
    group_by = ["alertname"]
    matcher {
      label = "alertname"
      match = "="
      value = "High Latency"
    }
    contact_point = grafana_contact_point.high_latency.name
    continue      = false

    group_wait      = "2s"
    group_interval  = "2s"
    repeat_interval = "5m"
  }
}


resource "grafana_machine_learning_job" "product_high_latency" {
  provider      = grafana.stack
  datasource_type = "prometheus"
  metric = "productservicelatency"
  name = "ProductServiceLatency"
  datasource_id = grafana_data_source.custom_prometheus.id
  query_params = {
    "editorMode" = "code"
    "expr" = "histogram_quantile(0.95, sum(rate(traces_spanmetrics_latency_bucket{service_name=~\"product\"}[10m])) by (le, service_name)) "
    "range" = "true"
    "refId" = "A"
  }
}

resource "grafana_rule_group" "high_latency" {
  provider         = grafana.stack
  name             = "Latency"
  folder_uid       = grafana_folder.ecommerce_app.uid
  interval_seconds = 10
  org_id           = 1
  rule {
    name           = "High Latency"
    for            = "11s"
    condition      = "B"
    no_data_state  = "OK"
    exec_err_state = "Error"
    annotations = {
      "SLO"              = "2.0s"
      "Value"            = "{{ humanizeDuration $values.C.Value }}"
      "__dashboardUid__" = "ihMHTlZVk/services-overview"
      "__panelId__"      = "7"
      "summary"          = "High Latency - {{ $labels.service_name }}"
    }
    labels = {
     
    }
    data {
      ref_id         = "A"
      datasource_uid = "grafanacloud-prom"
      relative_time_range {
        from = 60
        to   = 0
      }
      model = jsonencode({
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
        expr          = "histogram_quantile(.95, sum(rate(traces_spanmetrics_latency_bucket{}[1m])) by (le, service_name)) > 2000 < 86400000"
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = <<EOT
          {
              "conditions": [{
                "evaluator": {
                    "params": [0, 0],
                    "type": "gt"
                },
                "operator": {
                    "type": "and"
                },
                "query": {
                    "params": [ "A" ]
                },
                "reducer": {
                    "params": [],
                    "type": "avg"
                },
                "type": "query"
              }],
              "datasource": {
                "type": "__expr__",
                "uid": "-100"
              },
              "expression": "A",
              "hide": false,
              "intervalMs": 1000,
              "maxDataPoints": 43200,
              "reducer": "mean",
              "refId": "B",
              "type": "reduce"
          }
          EOT
    }

    data {
      ref_id         = "C"
      datasource_uid = "-100"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = <<EOT
          {
              "conditions": [{
                "evaluator": {
                    "params": [0, 0],
                    "type": "gt"
                },
                "operator": {
                    "type": "and"
                },
                "query": {
                    "params": [ "B" ]
                },
                "reducer": {
                    "params": [],
                    "type": "avg"
                },
                "type": "query"
              }],
              "datasource": {
                "type": "__expr__",
                "uid": "-100"
              },
              "expression": "$B / 1000.0",
              "hide": false,
              "intervalMs": 1000,
              "maxDataPoints": 43200,
              "refId": "C",
              "type": "math"
          }
          EOT
    }

  }
}

resource "grafana_rule_group" "too_many_connections" {
  provider         = grafana.stack
  name             = "db"
  folder_uid       = grafana_folder.ecommerce_app.uid
  interval_seconds = 10
  org_id           = 1
  rule {
    name           = "Too Many Open Postgres Clients"
    for            = "11s"
    condition      = "B"
    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    annotations = {
      "container"        = "product-data"
      "summary"          = "To many open postgres connections"
      "__dashboardUid__" = "wLEXziM4z/postgresql-database"
      "__panelId__"      = "44"
      "dashboard_url" = "${grafana_cloud_stack.stack.url}/d/wLEXziM4z/postgresql-database"
      "service" = "product-data"
    }
    labels = {
      "itsm" = "servicenow"
    }
    data {
      ref_id         = "A"
      datasource_uid = "grafanacloud-logs"
      relative_time_range {
        from = 60
        to   = 0
      }
      query_type = "range"
      model = jsonencode({
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        query_type    = "range"
        refId         = "A"
        expr          = "count by(k8s_container_name, k8s_pod_name) (rate({k8s_container_name=\"product-data\"} |= `too many clients` [$__interval]))"

      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "-100"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = <<EOT
          {
              "conditions": [{
                "evaluator": {
                    "params": [1, 0],
                    "type": "gt"
                },
                "operator": {
                    "type": "and"
                },
                "query": {
                    "params": [ "A" ]
                },
                "reducer": {
                    "params": [],
                    "type": "sum"
                },
                "type": "query"
              }],
              "datasource": {
                "type": "__expr__",
                "uid": "-100",
                "name": "Expression"
              },
              "expression": "A",
              "hide": false,
              "intervalMs": 1000,
              "maxDataPoints": 43200,
              "reducer": "sum",
              "refId": "B",
              "type": "classic_conditions",
              "settings": {
                "mode": "replaceNN",
                "replaceWithValue": 0
              }
          }
          EOT
    }
  }
}

resource "grafana_rule_group" "product_forecast_unusual_latency" {
  provider         = grafana.stack
  name             = "Ml Forecast Unusual Latency"
  folder_uid       = grafana_folder.ecommerce_app.uid
  interval_seconds = 10
  org_id           = 1
  rule {
    name           = "Unusual Latency"
    for            = "1m"
    condition      = "anomalous_value"
    no_data_state  = "NoData"
    exec_err_state = "Error"
    annotations = {
      "anomalous_actual" = "{{ $values.actual_value}}"
      "anomalous_predicted" ="{{ $values.predicted_value}}"
      "anomalous_value" = "{{ $values.anomalous_value}}"
      "dashboard_url" = "${grafana_cloud_stack.stack.url}/d/ihMHTlZVk/services-overview?orgId=1\u0026refresh=5s"
      "service" = "product"
      "grafana_ml_forecast_name" = grafana_machine_learning_job.product_high_latency.name
      "grafana_ml_forecast_url" = "${grafana_cloud_stack.stack.url}/a/grafana-ml-app/metric-forecast/${grafana_machine_learning_job.product_high_latency.id}"
      
    }
    labels = {
      "itsm" = "servicenow"
    }
    data {
      ref_id         = "anomalous"
      datasource_uid = "grafanacloud-ml-metrics"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "anomalous"
        expr          = "productservicelatency:anomalous"
      })
    }

    data {
      ref_id         = "actual"
      datasource_uid = "grafanacloud-ml-metrics"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "actual"
        expr          = "productservicelatency:actual{}"
      })
    }

    data {
      ref_id         = "predicted"
      datasource_uid = "grafanacloud-ml-metrics"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = jsonencode({
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "actual"
        expr          = "productservicelatency:predicted{}"
      })
    }

    data {
      ref_id         = "anomalous_value"
      datasource_uid = "-100"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = <<EOT
          {
              "conditions": [{
                "evaluator": {
                    "params": [0, 0],
                    "type": "gt"
                },
                "operator": {
                    "type": "and"
                },
                "query": {
                    "params": [  ]
                },
                "reducer": {
                    "params": [],
                    "type": "avg"
                },
                "type": "query"
              }],
              "datasource": {
                "name": "Expression",
                "type": "__expr__",
                "uid": "-100"
              },
              "expression": "anomalous",
              "hide": false,
              "intervalMs": 1000,
              "maxDataPoints": 43200,
              "reducer": "last",
              "refId": "anomalous_value",
              "type": "reduce"
          }
          EOT
    }

    data {
      ref_id         = "actual_value"
      datasource_uid = "-100"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = <<EOT
          {
              "conditions": [{
                "evaluator": {
                    "params": [0, 0],
                    "type": "gt"
                },
                "operator": {
                    "type": "and"
                },
                "query": {
                    "params": [  ]
                },
                "reducer": {
                    "params": [],
                    "type": "avg"
                },
                "type": "query"
              }],
              "datasource": {
                "name": "Expression",
                "type": "__expr__",
                "uid": "-100"
              },
              "expression": "actual",
              "hide": false,
              "intervalMs": 1000,
              "maxDataPoints": 43200,
              "reducer": "last",
              "refId": "actual_value",
              "type": "reduce"
          }
          EOT
    }

    data {
      ref_id         = "anomalous_value"
      datasource_uid = "-100"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = <<EOT
          {
              "conditions": [{
                "evaluator": {
                    "params": [0, 0],
                    "type": "gt"
                },
                "operator": {
                    "type": "and"
                },
                "query": {
                    "params": [  ]
                },
                "reducer": {
                    "params": [],
                    "type": "avg"
                },
                "type": "query"
              }],
              "datasource": {
                "name": "Expression",
                "type": "__expr__",
                "uid": "-100"
              },
              "expression": "anomalous",
              "hide": false,
              "intervalMs": 1000,
              "maxDataPoints": 43200,
              "reducer": "last",
              "refId": "anomalous_value",
              "type": "reduce"
          }
          EOT
    }

    data {
      ref_id         = "predicted_value"
      datasource_uid = "-100"
      relative_time_range {
        from = 300
        to   = 0
      }
      model = <<EOT
          {
              "conditions": [{
                "evaluator": {
                    "params": [0, 0],
                    "type": "gt"
                },
                "operator": {
                    "type": "and"
                },
                "query": {
                    "params": [  ]
                },
                "reducer": {
                    "params": [],
                    "type": "avg"
                },
                "type": "query"
              }],
              "datasource": {
                "name": "Expression",
                "type": "__expr__",
                "uid": "-100"
              },
              "expression": "predicted",
              "hide": false,
              "intervalMs": 1000,
              "maxDataPoints": 43200,
              "reducer": "last",
              "refId": "predicted_value",
              "type": "reduce"
          }
          EOT
    }
  }
}


resource "grafana_dashboard" "k6" {
  provider         = grafana.stack
  config_json = file("../grafana/dashboards/k6.json")
  folder = grafana_folder.ecommerce_app.id
  overwrite = true
}

resource "grafana_dashboard" "postgres" {
  provider         = grafana.stack
  config_json = file("../grafana/dashboards/postgres.json")
  folder = grafana_folder.ecommerce_app.id
  overwrite = true
}

resource "grafana_dashboard" "redis" {
  provider         = grafana.stack
  config_json = file("../grafana/dashboards/redis.json")
  folder = grafana_folder.ecommerce_app.id
  overwrite = true
}

resource "grafana_dashboard" "service_detail" {
  provider         = grafana.stack
  config_json = file("../grafana/dashboards/service_detail.json")
  folder = grafana_folder.ecommerce_app.id
  overwrite = true
}

resource "grafana_dashboard" "service_overview" {
  provider         = grafana.stack
  config_json = file("../grafana/dashboards/service_overview.json")
  folder = grafana_folder.ecommerce_app.id
  overwrite = true
}

resource "grafana_dashboard" "exec" {
  provider         = grafana.stack
  config_json = file("../grafana/dashboards/exec.json")
  folder = grafana_folder.ecommerce_app.id
  overwrite = true
}