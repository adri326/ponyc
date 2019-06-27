#!/bin/bash

pushd src >/dev/null
echo DIRECTORY `pwd`
for i in ../patches/*.diff; do
  echo TRYING PATCH $i
  if ! patch -R -p1 -s -f --dry-run <$i >/dev/null; then
    echo - APPLYING patch $i
    patch -p1 -s -f <$i
  else
    echo - NOT APPLYING patch $i, it is already applied
  fi
done
popd >/dev/null
