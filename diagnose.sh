#!/bin/bash

# Diagnostic script for webapp deployment
# Author: psyunix

echo "========================================="
echo "Webapp Deployment Diagnostics"
echo "========================================="
echo ""

echo "=== Namespace Status ==="
kubectl get namespace webapp
echo ""

echo "=== Deployment Status ==="
kubectl get deployment -n webapp
echo ""

echo "=== Pod Status ==="
kubectl get pods -n webapp -o wide
echo ""

echo "=== Service Status ==="
kubectl get svc -n webapp
echo ""

echo "=== Recent Events ==="
kubectl get events -n webapp --sort-by='.lastTimestamp' | tail -20
echo ""

echo "=== Pod Details ==="
POD=$(kubectl get pod -n webapp -l app=webapp -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$POD" ]; then
    echo "Describing pod: $POD"
    kubectl describe pod -n webapp $POD
    echo ""
    echo "=== Pod Logs ==="
    kubectl logs -n webapp $POD --tail=50 2>/dev/null || echo "No logs available yet"
else
    echo "No pods found"
fi

echo ""
echo "========================================="
echo "Diagnostics Complete"
echo "========================================="
