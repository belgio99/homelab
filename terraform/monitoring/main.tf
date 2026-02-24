terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.2"
    }
  }
}

variable "tenancy_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "fingerprint" {
  type = string
}

variable "region" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "instance_id" {
  type = string
}

resource "oci_identity_dynamic_group" "oracle_arm_instances" {
  compartment_id = var.compartment_id
  description    = "Dynamic group for oracle-arm instance to allow metrics scraping"
  matching_rule  = "Any {instance.id = '${var.instance_id}'}"
  name           = "oracle-arm-instances"
}

resource "oci_identity_policy" "oracle_arm_metrics_policy" {
  compartment_id = var.compartment_id
  description    = "Allow oracle-arm instances to push metrics and logs to OCI"
  name           = "oracle-arm-metrics-policy"
  statements     = [
    "Allow dynamic-group oracle-arm-instances to use metrics in tenancy",
    "Allow dynamic-group oracle-arm-instances to use log-content in compartment id ${var.compartment_id}"
  ]
}

resource "oci_logging_log_group" "k8s_log_group" {
  compartment_id = var.compartment_id
  display_name   = "kubernetes-logs"
  description    = "Log group for Kubernetes cluster logs"
}

resource "oci_logging_log" "k8s_fluentd_log" {
  display_name = "fluentd-logs"
  log_group_id = oci_logging_log_group.k8s_log_group.id
  log_type     = "CUSTOM"
  is_enabled   = true
}

output "fluentd_log_ocid" {
  value = oci_logging_log.k8s_fluentd_log.id
}

resource "oci_logging_unified_agent_configuration" "kube_state_metrics_agent_config" {
  compartment_id = var.compartment_id
  description    = "Scrape kube-state-metrics from the oracle-arm instance"
  display_name   = "kube-state-metrics-agent-config"
  is_enabled     = true

  group_association {
    group_list = [oci_identity_dynamic_group.oracle_arm_instances.id]
  }

  service_configuration {
    configuration_type = "MONITORING"

    application_configurations {
      source_type = "URL"

      destination {
        compartment_id    = var.compartment_id
        metrics_namespace = "kube_state_metrics"
      }

      source {
        name = "kube-state-metrics"
        scrape_targets {
          name = "kube-state-metrics"
          url  = "http://127.0.0.1:8080/metrics"
        }
      }
    }
  }
}
