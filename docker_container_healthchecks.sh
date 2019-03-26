#!/usr/bin/env bash
#
# Script to check container status and report to Discord if any of them are not running
# Tronyx

# Define some variables
tempDir='/tmp/'
containerNamesFile="${tempDir}container_names.txt"
discordWebhookURL=''

# Function to create list of Docker containers
create_containers_list() {
  docker ps --format '{{.Names}}' |sort > "${containerNamesFile}"
}

# Function to check Docker containers
check_containers() {
  while IFS= read -r container; do
    containerStatus=$(docker inspect "${container}" |jq .[].State.Status |tr -d '"')
    if [ "${containerStatus}" = 'running' ];then
      :
    elif [ "${containerStatus}" = 'exited' ];then
      curl -s -H "Content-Type: application/json" -X POST -d '{"content": "The '"${container}"' container is currently stopped!"}' "${discordWebhookURL}"
    elif [ "${containerStatus}" = 'dead' ];then
      curl -s -H "Content-Type: application/json" -X POST -d '{"content": "The '"${container}"' container is currently dead!"}' "${discordWebhookURL}"
    elif [ "${containerStatus}" = 'restarting' ];then
      curl -s -H "Content-Type: application/json" -X POST -d '{"content": "The '"${container}"' container is currently restarting!"}' "${discordWebhookURL}"
    elif [ "${containerStatus}" = 'paused' ];then
      curl -s -H "Content-Type: application/json" -X POST -d '{"content": "The '"${container}"' container is currently paused!"}' "${discordWebhookURL}"
    else
      curl -s -H "Content-Type: application/json" -X POST -d '{"content": "The '"${container}"' container currently has an unknown status!"}' "${discordWebhookURL}"
    fi
  done < <(cat "${containerNamesFile}")
}

# Main function to run all other functions
main() {
  create_containers_list
  check_containers
}

main
