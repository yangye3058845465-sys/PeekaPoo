#!/bin/bash

set -e
source /usr/local/Ascend/ascend-toolkit/set_env.sh

SOC_VERSION=${SOC_VERSION:-Ascend310B4}
MODEL_DIR=${MODEL_DIR:-$(dirname "$0")/../models}

for TASK in state bristol condition; do
    atc --model="$MODEL_DIR/$TASK.onnx" \
        --framework=5 \
        --output="$MODEL_DIR/$TASK" \
        --input_format=NCHW \
        --input_shape="image:1,3,224,224" \
        --soc_version="$SOC_VERSION" \
        --log=error
    echo "built $MODEL_DIR/$TASK.om"
done
