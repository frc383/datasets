#!/bin/bash

set -v  # print commands as they're executed
set -e  # fail and exit on any command erroring

function setup_env() {
  local py_version=$1
  local venv_path="tfds_env_${py_version}"
  virtualenv -p $py_version $venv_path
  source $venv_path/bin/activate
  pip install -q --upgrade setuptools pip
  pip install wheel twine pyopenssl
}

GIT_COMMIT_ID=${1:-""}
[[ -z $GIT_COMMIT_ID ]] && echo "Must provide a commit" && exit 1
SETUP_ARGS=""
if [ "$GIT_COMMIT_ID" = "nightly" ]
then
  GIT_COMMIT_ID="master"
  SETUP_ARGS="--nightly"
fi

TMP_DIR=$(mktemp -d)
pushd $TMP_DIR

echo "Cloning tensorflow/datasets and checking out commit $GIT_COMMIT_ID"
git clone https://github.com/tensorflow/datasets.git
cd datasets
git checkout $GIT_COMMIT_ID

setup_env python2

echo "Building source distribution"
python setup.py sdist $SETUP_ARGS

# Build the wheels
python setup.py bdist_wheel $SETUP_ARGS
setup_env python3
python setup.py bdist_wheel $SETUP_ARGS

# Publish to PyPI
read -p "Publish? (y/n) " -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "Publishing to PyPI"
  twine upload dist/*
else
  echo "Skipping upload"
  exit 1
fi

popd
rm -rf $TMP_DIR
