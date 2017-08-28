#!/usr/bin/env bash

#TODO: check for existing install of node

if [[ "$OSTYPE" == "linux-gnu" ]]; then
  curl -sL https://deb.nodesource.com/setup | sudo -E bash -
  sudo apt-get install -y nodejs
  # sudo apt-get install clang
  # libclang??

elif [[ "$OSTYPE" == "darwin"* ]]; then
  brew install node@6 npm
  # curl https://nodejs.org/dist/v4.3.0/node-v4.3.0.pkg > node.pkg
  # sudo installer -pkg node.pkg -target /
  brew install llvm
  ln -s $(brew --prefix llvm)/lib/libclang.dylib ./libclang.dylib
fi

npm install .
npm run build
./sauce.sh --config=$PROJECT_CONFIG setup
