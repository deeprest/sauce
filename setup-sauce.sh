#!/usr/bin/env bash


function clang
{
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    sudo apt-get install clang
    # libclang??
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install llvm
  fi
}

function node
{
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    #TODO: check for existing install of node
    sudo apt-get install nodejs #npm
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install node@6 npm
    # curl https://nodejs.org/dist/v4.3.0/node-v4.3.0.pkg > node.pkg
    # sudo installer -pkg node.pkg -target /
  fi
}

function sauce
{
  #clang
  #node
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    npm install .
    ./coffee.sh
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    ln -s $(brew --prefix llvm)/lib/libclang.dylib ./libclang.dylib
    npm install .
    ./coffee.sh
  fi
}

clang
node
sauce
