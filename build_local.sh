#!/bin/bash

root=$(git rev-parse --show-toplevel)
docker build -t build-image $root

docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/workdir --entrypoint /usr/bin/luet -w /workdir build-image build \
      -q --only-target-package \
      --pull-repository quay.io/mocaccino/desktop \
      --pull --image-repository local-repo --from-repositories --no-spinner --live-output --tree packages "$@"

