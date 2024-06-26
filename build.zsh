cd "$(dirname "$0")"
cd ./

set -eu

PLUGIN="tridecimator"
echo ${PLUGIN}

mkdir -p ${PLUGIN}.plugin/Contents/MacOS
clang++ -std=c++20 -Wc++20-extensions -bundle -fobjc-arc -O3 -I ./ -I./eigen/3.4.0_1/include/eigen3 -framework Cocoa ./tridecimator.mm -o ./${PLUGIN}.plugin/Contents/MacOS/${PLUGIN}
cp ./Info.plist ./${PLUGIN}.plugin/Contents/

# codesign --force --options runtime --deep --entitlements "../CPU/entitlements.plist" --sign "Developer ID Application" --timestamp --verbose ${PLUGIN}.plugin

echo "** BUILD SUCCEEDED **"
