#!/bin/sh

set -eu

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER is not set; leaving CURRENT_PROJECT_VERSION unchanged."
  exit 0
fi

cd "${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"

echo "Setting CURRENT_PROJECT_VERSION to Xcode Cloud build number ${CI_BUILD_NUMBER}."

project_file="LiftingLog.xcodeproj/project.pbxproj"

if [ ! -f "${project_file}" ]; then
  echo "Expected Xcode project file not found: ${project_file}" >&2
  exit 1
fi

perl -0pi -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $ENV{CI_BUILD_NUMBER};/g' "${project_file}"
