terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
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
  description    = "Allow oracle-arm instances to push metrics to OCI Monitoring"
  name           = "oracle-arm-metrics-policy"
  statements     = [
    "Allow dynamic-group oracle-arm-instances to use metrics in tenancy"
  ]
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
