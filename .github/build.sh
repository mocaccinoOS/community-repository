#!/bin/bash

sudo -E luet build \
        --only-target-package \
        --pull-repository quay.io/mocaccino/os-commons \
        --pull-repository $PULL_REPOSITORY \
        --pull --push --image-repository $FINAL_REPO \
        --from-repositories --no-spinner --live-output --tree $PWD/packages "$1"

#sudo -E luet build \
#        --only-target-package \
#        --plugin cleanup-images \
#        --pull-repository quay.io/mocaccino/os-commons \
#        --pull-repository $PULL_REPOSITORY \
#        --pull --push --image-repository $FINAL_REPO \
#        --from-repositories --no-spinner --live-output --tree $PWD/packages "$1"
