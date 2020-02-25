#!/bin/bash

# This file follows the directions that are outlined here: 
# https://www.redhat.com/en/blog/custom-grafana-dashboards-red-hat-openshift-container-platform-4

if [ -z "$1" ]; then
    PROJECT_NAME="debezium-monitoring"
else
    PROJECT_NAME="$1"
fi

if [ -z "$2" ]; then
    ADMIN_PASSWORD="openshift"
else
    ADMIN_PASSWORD="$2"
fi

oc new-project $PROJECT_NAME --display-name="Custom Debezium Monitoring" \
    --description "A separate Grafana installation that allows the addition of custom dashboards"

oc process -f $DEMO_HOME/kube/grafana/grafana-community-subscription-template.yaml PROJECT_NAME="${PROJECT_NAME}" -o yaml | oc apply -f -

# can't seem to wait on the operator itself, maybe waiting on the deployment is good enough
oc wait --for=condition=available deployment/grafana-operator

oc process -f $DEMO_HOME/kube/grafana/grafana-instance-template.yaml PROJECT_NAME="${PROJECT_NAME}" \
    ADMIN_PASSWORD="${ADMIN_PASSWORD}" -o yaml | oc apply -f -

# Wait until grafana instance is deployed
oc wait --for=condition=available deployment/grafana-deployment

# Patch Prometheus so that it can connect with the customer grafana instance in our project
# FIXME: doing by index of array seems dangerous, but it doesn't appear that there is another way to do this with patching
# specifications
oc patch statefulsets/prometheus-k8s -n openshift-monitoring --type='json' \
    -p='[ { "op": "replace", "path": "/spec/template/spec/containers/0/args/9","value": "--web.listen-address=:9090" }]'

# PRint out the route
echo "https://$(oc get route grafana-route -o jsonpath='{.spec.host}' -n ${PROJECT_NAME})/"