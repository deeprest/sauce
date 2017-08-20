#!/usr/bin/env bash

function clang
{
  #TODO: check for clang
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    echo clang
    # sudo apt-get install clang
    # libclang??
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install llvm
  fi
}

function nodejs
{
  #TODO: check for existing install of node
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    echo nodejs
    # sudo apt-get install nodejs #npm
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install node@6 npm
    # curl https://nodejs.org/dist/v4.3.0/node-v4.3.0.pkg > node.pkg
    # sudo installer -pkg node.pkg -target /
  fi
}

function sauce
{
  #clang
  #nodejs
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    npm install .
    npm run build
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    ln -s $(brew --prefix llvm)/lib/libclang.dylib ./libclang.dylib
    npm install .
    npm run build
  fi
}

#clang
#nodejs
sauce
