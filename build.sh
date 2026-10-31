#!/bin/bash
set -e

echo "Building yard-rspec-coverage..."
echo "==============================="

echo "Installing dependencies..."
bundle install

# Fails without network access, rather than auditing against outdated advisories.
echo "Updating the bundler-audit advisory database..."
bundle exec rake bundle:audit:update

echo "Running checks and generating documentation..."
bundle exec rake default yard:doc

echo ""
echo "Build complete! Documentation generated in doc/"
echo "Open doc/index.html to view the documentation."
