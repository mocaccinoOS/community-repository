#!/bin/bash

sudo -E luet build \
        --only-target-package \
        --pull-repository $PULL_REPOSITORY \
        --pull --push --image-repository $FINAL_REPO \
        --from-repositories --no-spinner --live-output --tree packages "$1"