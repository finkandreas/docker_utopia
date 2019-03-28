#!/bin/bash

set -e
set -x

for i in {1..6} ; do
    docker images | grep -v utopia_ubuntu | grep -q stage0${i} || ( docker build -t=finkandreas/utopia:stage0${i} -f Dockerfile.stage0${i} . && docker push finkandreas/utopia:stage0${i} )
done

