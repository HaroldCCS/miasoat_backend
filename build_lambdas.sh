#!/bin/bash
set -e

mkdir -p bin

echo "Building Go lambdas..."
for func in users_signup create_events send_email; do
  cd cmd/$func
  GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o bootstrap main.go
  echo "Zipping $func..."
  zip -j ../../bin/$func.zip bootstrap
  rm bootstrap
  cd ../..
done

echo "Building Node js lambda..."
cd cmd/scrapping_per_user
npm install --cache /tmp/npm-cache
zip -r ../../bin/scrapping_per_user.zip index.js package.json node_modules
cd ../..

echo "All lambdas built in bin/"
