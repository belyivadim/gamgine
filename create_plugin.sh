#!/bin/bash

if [ -z "$1" ]
then
  echo "Please provide a plugin destination path."
  exit 1
fi

cp ./src/engine/core/plugin_template.zig $1

if [ $? == "0" ]
then
  echo "Plugin created at $1"
  exit 0
else
  exit 1
fi

