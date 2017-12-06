#!/bin/bash

# bring up all
docker-compose up -d
sleep 15

# enable federation plugin
docker-compose exec rabbitmq-1 rabbitmq-plugins enable rabbitmq_federation rabbitmq_federation_management
# docker-compose exec rabbitmq-2 rabbitmq-plugins enable rabbitmq_federation rabbitmq_federation_management
# docker-compose exec rabbitmq-3 rabbitmq-plugins enable rabbitmq_federation rabbitmq_federation_management

# get url for sender
RABBIT_1=$(docker-compose port rabbitmq-1 15672)
# # get url for the federated
# RABBIT_2=$(docker-compose port rabbitmq-2 15672)
# # get url for receiver
# RABBIT_3=$(docker-compose port rabbitmq-3 15672)

VHOST=%2f

# add vhost on rabbitmq-1
http -a rabbit:rabbit PUT http://$RABBIT_1/api/vhosts/core
http -a rabbit:rabbit PUT http://$RABBIT_1/api/vhosts/aux
# allow rabbit user to vhosts
http -a rabbit:rabbit PUT http://$RABBIT_1/api/permissions/core/rabbit configure=".*" write=".*" read=".*"
http -a rabbit:rabbit PUT http://$RABBIT_1/api/permissions/aux/rabbit configure=".*" write=".*" read=".*"

# rabbitmq1 <-x-> rabbitmq2 <-x rabbitmq3

# set up intrahost link
http -a rabbit:rabbit PUT http://$RABBIT_1/api/parameters/federation-upstream/aux/vhost-upstream value:='{"uri":"amqp://rabbit:rabbit@rabbitmq-1/core","expires":3600000}'
http -a rabbit:rabbit PUT http://$RABBIT_1/api/parameters/federation-upstream/core/vhost-upstream value:='{"uri":"amqp://rabbit:rabbit@rabbitmq-1/aux","expires":3600000}'

# set up upstreams on downstreamers
# http -a rabbit:rabbit PUT http://$RABBIT_1/api/parameters/federation-upstream/$VHOST/main-upstream value:='{"uri":"amqp://rabbit:rabbit@rabbitmq-2","expires":3600000}'
# http -a rabbit:rabbit PUT http://$RABBIT_2/api/parameters/federation-upstream/$VHOST/main-upstream value:='{"uri":"amqp://rabbit:rabbit@rabbitmq-1","expires":3600000}'
# http -a rabbit:rabbit PUT http://$RABBIT_2/api/parameters/federation-upstream/$VHOST/main-upstream value:='{"uri":"amqp://rabbit:rabbit@rabbitmq-3","expires":3600000}'

# set up grab-all policy on downstreamers
http -a rabbit:rabbit PUT  http://$RABBIT_1/api/policies/aux/vhost-fedex pattern="." definition:='{"federation-upstream-set":"all"}' apply-to="exchanges"
http -a rabbit:rabbit PUT  http://$RABBIT_1/api/policies/core/vhost-fedex pattern="." definition:='{"federation-upstream-set":"all"}' apply-to="exchanges"
# http -a rabbit:rabbit PUT  http://$RABBIT_1/api/policies/$VHOST/fedex pattern="^amq\." definition:='{"federation-upstream-set":"all"}' apply-to="exchanges"
# http -a rabbit:rabbit PUT  http://$RABBIT_2/api/policies/$VHOST/fedex pattern="^amq\." definition:='{"federation-upstream-set":"all"}' apply-to="exchanges"


# send a message to the upstreamer
hey -a rabbit:rabbit -T application/json -m POST -d '{"vhost":"/core","name":"amq.fanout","properties":{"delivery_mode":1},"routing_key":"","delivery_mode":"1","payload":"{\"blah\":\"blah\"}","payload_encoding":"string"}' http://$RABBIT_1/api/exchanges/core/amq.fanout/publish
hey -a rabbit:rabbit -T application/json -m POST -d '{"vhost":"/aux","name":"amq.fanout","properties":{"delivery_mode":1},"routing_key":"","delivery_mode":"1","payload":"{\"blah\":\"blah\"}","payload_encoding":"string"}' http://$RABBIT_1/api/exchanges/aux/amq.fanout/publish
# hey -a rabbit:rabbit -T application/json -m POST -d '{"vhost":"/","name":"amq.fanout","properties":{"delivery_mode":1},"routing_key":"","delivery_mode":"1","payload":"{\"blah\":\"blah\"}","payload_encoding":"string"}' http://$RABBIT_1/api/exchanges/$VHOST/amq.fanout/publish
# hey -a rabbit:rabbit -T application/json -m POST -d '{"vhost":"/","name":"amq.fanout","properties":{"delivery_mode":1},"routing_key":"","delivery_mode":"1","payload":"{\"blah\":\"blah\"}","payload_encoding":"string"}' http://$RABBIT_2/api/exchanges/$VHOST/amq.fanout/publish
# hey -a rabbit:rabbit -T application/json -m POST -d '{"vhost":"/","name":"amq.fanout","properties":{"delivery_mode":1},"routing_key":"","delivery_mode":"1","payload":"{\"blah\":\"blah\"}","payload_encoding":"string"}' http://$RABBIT_3/api/exchanges/$VHOST/amq.fanout/publish
