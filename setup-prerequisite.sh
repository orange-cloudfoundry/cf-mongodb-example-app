#!/usr/bin/env bash
set -e
echo "Processing $0"
SERVICE_ADMIN_USERNAME="$SERVICE_USERNAME-admin"
service_container_id=$(docker run -d --rm -p "$SERVICE_PORT:$SERVICE_PORT" \
	-e MONGO_INITDB_ROOT_USERNAME=$SERVICE_ADMIN_USERNAME \
	-e MONGO_INITDB_ROOT_PASSWORD=$SERVICE_PASSWORD \
	-e MONGO_INITDB_DATABASE="$DATABASE_NAME" \
  --name "$SERVICE_NAME-service" \
  --health-cmd "$SERVICE_HEALTH_CMD" \
  --health-interval 10s --health-timeout 5s --health-retries 5 \
  ${SERVICE_IMAGE} --port $SERVICE_PORT)
docker logs -f "$SERVICE_NAME-service" &> "$SERVICE_NAME-service.log" &
echo "Waiting for $SERVICE_NAME-service"
sleep 5
if [ -z "$service_container_id" ];then
  echo "ERROR: failed to start container '$SERVICE_NAME-service' using $SERVICE_IMAGE"
else
  echo "'$SERVICE_NAME-service' is running $SERVICE_IMAGE"
fi
service_container_name="$(docker ps -f "ancestor=$SERVICE_IMAGE" --format "{{.Names}}")"
SERVICE_CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$service_container_name")
echo "$SERVICE_CONTAINER_IP: $SERVICE_CONTAINER_IP"
export SERVICE_HOST=$SERVICE_CONTAINER_IP
echo "$SERVICE_NAME - Mongosh version: $(docker exec -i $service_container_name mongosh --version)"
echo "$SERVICE_NAME - Cmd to create user: mongosh --username '$SERVICE_ADMIN_USERNAME' -p '$SERVICE_PASSWORD' --authenticationDatabase admin --eval \"use $DATABASE_NAME; db.createUser({ user: '$SERVICE_USERNAME', pwd: '$SERVICE_PASSWORD', roles: [{ role: 'readWrite,userAdmin', db: '$DATABASE_NAME' }] })\""
docker exec -i $service_container_name bash -c "mongosh \"mongodb://$SERVICE_ADMIN_USERNAME:$SERVICE_PASSWORD@localhost:$SERVICE_PORT/$DATABASE_NAME\" --authenticationDatabase admin <<EOF
 db.createUser({ user: '$SERVICE_USERNAME', pwd: '$SERVICE_PASSWORD',
  roles: [
  { role: 'readWrite', db: '$DATABASE_NAME' }
  //, { role: 'userAdmin', db: '$DATABASE_NAME' }
  ] })
 show users
EOF
"
# EOF is implicit on github-action, but required locally,

echo ""

echo "To ease connection to mongo server, execute the command below: "
echo "docker exec -i $service_container_name bash -c \"mongosh 'mongodb://$SERVICE_USERNAME:$SERVICE_PASSWORD@$SERVICE_HOST:$SERVICE_PORT/$DATABASE_NAME' --authenticationDatabase admin --eval 'db.getUsers()'\""

echo "SERVICE_HOST: $SERVICE_HOST"
