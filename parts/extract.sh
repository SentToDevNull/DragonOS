#!/bin/bash

# determine the compression of your tarball
ext=$(echo $(find . -name "$1*.xz" -or -name "$1*.gz" -or -name "$1*.bz2") | rev | cut -f 1 -d '.' | rev)

echo $ext

if [ "$ext" == "xz" ]; then
  tar xvJf $1*.xz
elif [ "$ext" == "gz" ]; then
  tar xvzf $1*.gz
elif [ "$ext" == "bz2" ]; then
  tar xvjf $1*.bz2
fi
