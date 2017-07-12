!#/bin/bash
# Kill all running containers.
docker kill $(docker ps -q)

# Delete all stopped containers.
printf "\n>>> Deleting stopped containers\n\n" && docker rm $(docker ps -a -q)

# Delete all images.
printf "\n>>> Deleting untagged images\n\n" && docker rmi $(docker images -q)

# Delete all volumes
docker volume rm $(docker volume ls -qf)
