#!/bin/bash

echo "==================================="
echo "Resetting Database Deployments"
echo "==================================="

# Delete existing database resources
echo "Removing existing PostgreSQL StatefulSet..."
kubectl delete statefulset postgresql -n database --ignore-not-found=true
kubectl delete pvc postgres-storage-postgresql-0 -n database --ignore-not-found=true

echo "Removing existing deployments..."
kubectl delete deployment redis rabbitmq -n database --ignore-not-found=true

echo "Waiting for cleanup..."
sleep 10

echo "Database resources cleaned. You can now run the deploy script."
