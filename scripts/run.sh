#!/bin/bash

root=$(git rev-parse --show-toplevel)
docker build -t desktop-scripts $root/scripts

script=$1
shift

set -ex
echo "2: ${ROOT_PATH}"
docker run -v $root:/work --workdir /work --entrypoint /bin/bash --rm desktop-scripts -c "bash scripts/$script $@"