#!/bin/bash

for file in 0PCL/0PCLExamples/3Wrong/*
do
  echo "$file:"
  cabal run < $file
  echo ""
done
