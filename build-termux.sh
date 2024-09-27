#!/bin/bash
cd "$(dirname "$0")"
if [ "$#" -ne 1 ]
then 
    echo "usage: $0 [custom.package.name]"
    exit 1
fi
PACKAGE_NAME=$1
if [[ $PACKAGE_NAME =~ '_' ]] || [[ $PACKAGE_NAME =~ '-' ]] 
then
    echo "package name must not contain underscore, dash, or possibly other characters!"
    exit 2
fi
PACKAGE_NAME_UNDERSCORE=$(echo "$PACKAGE_NAME" | tr . _)
PACKAGE_NAME_ARRAY=
split_package_name() {
    PACKAGE_NAME_INNER=$1
    local -n PACKAGE_NAME_ARRAY_INNER=$2
    IFS='.'
    read -a PACKAGE_NAME_ARRAY <<< "$PACKAGE_NAME"
}
split_package_name PACKAGE_NAME PACKAGE_NAME_ARRAY
unset split_package_name

./clean.sh

# Version originally tested
# PLAY_STORE_TERMUX_PACKAGES_GIT_HASH=a41fd427b94dda5724edf9e1e1f5278fc6e7453e
# PLAY_STORE_TERMUX_APPS_GIT_HASH=63dd74e8c5c2bbb8ee28d82e7eb0874902786849
# PLAY_STORE_TERMUX_PACKAGES_SHA256SUM=0e5045009ac752ed30a137ffc522090880583e8ca4c969e51db7b62809701e9c
# PLAY_STORE_TERMUX_APPS_SHA256SUM=760a0ebc90746d244e73dd5e635e0900d5b855f72e284837fdfb9f5e67bc498e

# wget -nc https://github.com/termux-play-store/termux-apps/archive/$PLAY_STORE_TERMUX_APPS_GIT_HASH.zip || exit 3
# wget -nc https://github.com/termux-play-store/termux-packages/archive/$PLAY_STORE_TERMUX_PACKAGES_GIT_HASH.zip || exit 4

# echo "$PLAY_STORE_TERMUX_PACKAGES_SHA256SUM $PLAY_STORE_TERMUX_PACKAGES_GIT_HASH.zip" | sha256sum --check --status || exit 5
# echo "$PLAY_STORE_TERMUX_APPS_SHA256SUM $PLAY_STORE_TERMUX_APPS_GIT_HASH.zip" | sha256sum --check --status || exit 6

wget -nc https://github.com/termux-play-store/termux-apps/archive/main.zip || exit 3
mv main.zip termux-apps.zip
wget -nc https://github.com/termux-play-store/termux-packages/archive/main.zip || exit 4
mv main.zip termux-packages.zip

unzip "*.zip" || exit 7

pushd termux-packages-* || exit 8

patch -p1 < ../name-change-helper.patch || exit 9

sed -i "s/TERMUX_APP_PACKAGE=\"com.termux\"/TERMUX_APP_PACKAGE=\"$PACKAGE_NAME\"/g" scripts/properties.sh || exit 10

scripts/run-docker.sh scripts/generate-bootstraps.sh --build || exit 11

popd

cp termux-packages-*/bootstrap-*.zip termux-apps-*/termux-app/src/main/cpp/ || exit 12

pushd termux-apps-* || exit 13

patch -p1 < ../local-bootstraps.patch || exit 14

find . -type f -exec sed -i -e "s/>Termux</>$PACKAGE_NAME</g" \
                            -e "s/\"Termux\"/\"$PACKAGE_NAME\"/g" \
                            -e "s/com\.termux/$PACKAGE_NAME/g" \
                            -e "s/com_termux/$PACKAGE_NAME_UNDERSCORE/g" {} \;

move_termux_folder() {
    COM_FOLDER="$1"/..
    cd "${COM_FOLDER}"
    for folder in ${PACKAGE_NAME_ARRAY[@]}
    do
        mkdir $folder
        cd $folder
    done
    mv "${COM_FOLDER}"/termux/* .
    rm -r "${COM_FOLDER}"/termux/
}
find . -type d -name termux -exec move_termux_folder {} \;
unset move_termux_folder

./gradlew assembleDebug || exit 15

cp termux-app/build/outputs/apk/debug/*.apk ..

popd
