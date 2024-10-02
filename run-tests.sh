#!/usr/bin/env bash
set -e

./vcap-services-template-reformat.sh
cat vcap-service.env
echo "Starting sample app"
container_name="cnb-app-container"
container_id=$(docker run -d --rm -e PORT=80 -p 8080:80 --env-file vcap-service.env --name "$container_name" ${CNB_IMAGE_NAME})

echo "Cnb app started (id: $container_id)"
echo "Waiting to ensure app is up and running"
while [ "$( docker container inspect -f '{{.State.Status}}' $container_name )" != "running" ]; do
  echo "waiting for $container_name to be running current: $(docker inspect -f '{{.State.Status}}' $container_name)"
  sleep 1
done
sleep 3 # to ensure app is up and running
#docker inspect -f '{{.HostConfig.LogConfig.Type}}' $container_id
service_container_name="$(docker ps -f "ancestor=$SERVICE_IMAGE" --format "{{.Names}}")"
CONTAINER_APP_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_name)
echo "CONTAINER_APP_IP: $CONTAINER_APP_IP"

if [ "$DEBUG" = "1" ]; then
  echo "----------------- $container_name --------------------"
  docker inspect -f '{{json .NetworkSettings}}' $container_name

  echo "----------------- $SERVICE_NAME: $service_container_name --------------------"
  docker inspect -f '{{json .NetworkSettings}}' "$service_container_name"
fi
echo "=== Redirect logs to cnb-app-container.log ==="
docker logs -f cnb-app-container &> cnb-app-container.log &
docker ps -a

echo "=== Check connectivity ==="
if nc -vz 127.0.0.1 8080;then echo "port 8080 available";else echo "port 8080 UNAVAILABLE";exit_status=1;fi
if nc -vz 127.0.0.1 "${SERVICE_PORT}";then echo "port ${SERVICE_PORT} available";else echo "port ${SERVICE_PORT} UNAVAILABLE";exit_status=1;fi
#echo "Checking redis server 127.0.0.1 : PING ==> $(redis-cli -a ${SERVICE_PASSWORD} -h 127.0.0.1 -p ${SERVICE_PORT} --no-auth-warning ping)"
#echo "Checking redis server $SERVICE_HOST : PING ==> $(redis-cli -a ${SERVICE_PASSWORD} -h ${SERVICE_HOST} -p ${SERVICE_PORT} --no-auth-warning ping)"

echo mongosh \'mongodb://$SERVICE_USERNAME:$SERVICE_PASSWORD@$SERVICE_HOST:$SERVICE_PORT/$DATABASE_NAME\' --apiVersion 1


function check_service() {
  type="$1"
  cmd="$2"
  cmd_prefix="$3"
  if [ -z "$cmd_prefix" ];then
    cmd_prefix="curl"
  fi
  status=0
  echo "$type using > $cmd <"  1>&2
  if ! $cmd;then
    echo ""  1>&2
    echo "$type failed: retry in verbose mode" 1>&2
    $cmd_prefix -vvv ${cmd##$cmd_prefix}
    status=1
  else
    echo ""  1>&2
    echo "$type successful" 1>&2
  fi
  echo "check_service - status: $status" 1>&2
  return $status
}
export APP="http://127.0.0.1:8080"
set +e
exit_status=0
create_service_output="$(check_service "Create" "curl -sSLf -X POST $APP/myCollection -d ''")"
create_service=$?

#get_service_output="$(check_service "Get" "curl -sSLf -X GET $APP/foo" )"
#get_service=$?

delete_service_output="$(check_service "Delete" "curl -sSLf DELETE $APP/myCollection -d ''")"
delete_service=$?
set -e

exit_status=$(($create_service + $delete_service))
echo "exit status: $exit_status"
echo "======================================================================================================"
echo "Dumping logs using docker logs cnb-app-container"
docker logs cnb-app-container 2>&1
ls -lrt *.log

if [ $exit_status -ne 0 ];then
  echo "-------------------------------------------------------------------------------------------------"
  echo "Dumping service logs"
  docker logs $SERVICE_NAME-service -n 30 2>&1
fi
exit $exit_status
