# Observability Proof (latest)

## 1) Metrics API (cluster-level)
- metrics_api.txt: Metrics APIService is available
- top_nodes.txt: Node CPU/Memory metrics
- top_pods_head.txt: Top pods snapshot (head 40)

## 2) Prometheus Operator objects (app-level + k8s-level)
- monitoring_dev_objects.txt: Prometheus/Alertmanager/ServiceMonitor/Rules (dev)
- monitoring_prod_objects.txt: Prometheus/Alertmanager/ServiceMonitor/Rules (prod)

## 3) Metrics-server runtime spec
- metrics_server_deploy.yaml: current Deployment spec used in cluster
  - NOTE: kubectl.kubernetes.io/last-applied-configuration may differ from current args due to post-apply patches.
