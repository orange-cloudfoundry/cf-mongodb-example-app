#!/usr/bin/env bash
set -e
echo "Processing $0"

service_container_id=$(docker run -d --rm -p "$SERVICE_PORT:27017" \
	-e MONGO_INITDB_ROOT_USERNAME="$SERVICE_USERNAME" \
	-e MONGO_INITDB_ROOT_PASSWORD="$SERVICE_PASSWORD" \
	-e MONGO_INITDB_DATABASE="$DATABASE_NAME" \
  --name "$SERVICE_NAME-service" \
  --health-cmd "$SERVICE_HEALTH_CMD" \
  --health-interval 10s --health-timeout 5s --health-retries 5 \
  ${SERVICE_IMAGE} --tlsMode disabled)
echo "Waiting for $SERVICE_NAME-service"
sleep 2
if [ -z "$service_container_id" ];then
  echo "ERROR: failed to start container '$SERVICE_NAME-service' using $SERVICE_IMAGE"
else
  echo "'$SERVICE_NAME-service' is running $SERVICE_IMAGE"
fi
service_container_name="$(docker ps -f "ancestor=$SERVICE_IMAGE" --format "{{.Names}}")"
SERVICE_CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$service_container_name")
echo "$SERVICE_CONTAINER_IP: $SERVICE_CONTAINER_IP"
export SERVICE_HOST=$SERVICE_CONTAINER_IP
echo "Mongosh version: $(docker exec -i $service_container_name mongosh --version)"
echo "SERVICE_HOST: $SERVICE_HOST"
