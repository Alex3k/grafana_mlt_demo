#!/bin/bash
kubectl scale --replicas=0 deploy/k6

kubectl exec deploy/product-data -- psql --username "user3" postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'user2';"

kubectl exec deploy/product-data -- psql --username "user3" postgres -c "SELECT pg_sleep(240);" &
kubectl exec deploy/product-data -- psql --username "user4" postgres -c "SELECT pg_sleep(240);" &
kubectl exec deploy/product-data -- psql --username "user5" postgres -c "SELECT pg_sleep(240);" &
kubectl exec deploy/product-data -- psql --username "user6" postgres -c "SELECT pg_sleep(240);" &
kubectl exec deploy/product-data -- psql --username "user7" postgres -c "SELECT pg_sleep(240);" &

kubectl scale --replicas=1 deploy/k6
