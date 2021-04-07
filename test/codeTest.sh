#!/bin/bash

credoStatus="found no issues"
outCredo=/tmp/outCredo.txt
export ELIXIR_WARNINGS_AS_ERRORS=true

mix local.rebar --force
mix local.hex --force
mix deps.get

echo "!!!Running test mix coveralls!!!"
MIX_ENV=test mix coveralls

# Check temp dir for dialyzer
if [ -z "$1" ]
  then
    echo "Error: The project path is null!"
    exit 1
  else 
    echo "The project path is: $1"
fi

# Creating plts path
mkdir -p /builds/$1/priv/plts

echo "!!!Running mix credo!!!"
mix credo --strict > $outCredo
if grep -q "$credoStatus" $outCredo; then
    cat $outCredo
  echo "Mix Credo Found NO Issues!!!"
else
    cat $outCredo
  echo "mix credo found issues! please review your code!"
  exit 1
fi

echo "!!!Running mix dialyzer!!!"
mix dialyzer --halt-exit-status
