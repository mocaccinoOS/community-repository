#!/bin/bash

root=$(git rev-parse --show-toplevel)

BASEDIR=$(dirname "$0")
if [ -z "$root" ]; then
  root=$BASEDIR
fi

pushd $root

docker build -t build-image $root

docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:/workdir --entrypoint /usr/bin/luet -w /workdir build-image build \
      -q --only-target-package \
      --pull-repository quay.io/mocaccino/desktop \
      --pull-repository quay.io/mocaccino/os-commons \
      --pull-repository quay.io/mocaccino/extra \
      --pull --image-repository local-repo --from-repositories --no-spinner --live-output --tree packages "$@"

