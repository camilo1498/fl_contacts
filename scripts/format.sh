#!/bin/bash

set -ex

dart format .

swiftformat --swiftversion 5.9 .

ktlint -F
