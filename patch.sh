#!/usr/bin/env bash
NIFI_TAG="$1"

function patch() {
  PACKAGE="liquid-$1"
  TARGET_PACKAGE="nifi-$1"

  find /opt/nifi/build/build/$PACKAGE/patch/ -type f | while read patch_file
  do
    target_file=${patch_file/build\/$PACKAGE\/patch/$TARGET_PACKAGE}
    echo "Patching $target_file"
    # Safety newline
    echo "" >> $target_file
    cat $patch_file >> $target_file
  done
}

function copy_media() {
  PACKAGE="liquid-$1"
  TARGET_PACKAGE="nifi-$1"

  find /opt/nifi/build/build/$PACKAGE/copy/media/ -type f -printf "%f\n" | while read copy_file
  do
    source_file=/opt/nifi/build/build/$PACKAGE/copy/media/$copy_file
    target_directory=/opt/nifi/build/$TARGET_PACKAGE/media/
    echo "Copying font $source_file"
    cp $source_file $target_directory
  done
}

function replace_media() {
  PACKAGE="liquid-$1"
  TARGET_PACKAGE="nifi-$1"

  find /opt/nifi/build/build/$PACKAGE/replace/media/ -type f -printf "%f\n" | while read replace_file
  do
    length=$((${#replace_file}-4))
    raw_name=${replace_file:0:length}
    extension=${replace_file:length:4}
    source_file=/opt/nifi/build/build/$PACKAGE/replace/media/$replace_file
    target_file=$(find /opt/nifi/build/$TARGET_PACKAGE/media/ -name ${raw_name}-*$extension)
    echo "Replacing $target_file"
    cp $source_file $target_file
  done
}

function unpack_package() {
  PACKAGE_NAME="$1"

  cp /opt/nifi/build/nifi-server/META-INF/bundled-dependencies/nifi-$PACKAGE_NAME-$NIFI_TAG.war /opt/nifi/build/nifi-$PACKAGE_NAME/nifi-$PACKAGE_NAME.war
  unzip /opt/nifi/build/nifi-$PACKAGE_NAME/nifi-$PACKAGE_NAME.war -d /opt/nifi/build/nifi-$PACKAGE_NAME/
}

function zip_package() {
  PACKAGE_NAME="$1"

  cd /opt/nifi/build/nifi-$PACKAGE_NAME/ && zip -r /opt/nifi/build/nifi-$PACKAGE_NAME/nifi-$PACKAGE_NAME-patched.war * -x nifi-$PACKAGE_NAME.war
  cp /opt/nifi/build/nifi-$PACKAGE_NAME/nifi-$PACKAGE_NAME-patched.war /opt/nifi/build/nifi-server/META-INF/bundled-dependencies/nifi-$PACKAGE_NAME-$NIFI_TAG.war
}

function patch_old_ui_package() {
  PACKAGE_NAME="$1"

  unpack_package $PACKAGE_NAME
  cp -r /opt/nifi/build/build/liquid-$PACKAGE_NAME/replace/* /opt/nifi/build/nifi-$PACKAGE_NAME/
  patch $PACKAGE_NAME
  zip_package $PACKAGE_NAME
}

function unzip_server_nar() {
  cp /opt/nifi/nifi-current/lib/nifi-server-nar-$NIFI_TAG.nar /opt/nifi/build/nifi-server/nifi-server.nar
  unzip /opt/nifi/build/nifi-server/nifi-server.nar -d /opt/nifi/build/nifi-server/
}

function patch_old_ui() {
  mkdir -p /opt/nifi/build/nifi-web-ui
  mkdir -p /opt/nifi/build/nifi-web-docs

  patch_old_ui_package web-ui
  patch_old_ui_package web-docs
}

function patch_new_ui() {
  mkdir -p /opt/nifi/build/nifi-ui

  unpack_package ui

  # Rename styles file to a version without hash
  STYLES_FILENAME=$(ls /opt/nifi/build/nifi-ui/ | grep "styles")
  mv /opt/nifi/build/nifi-ui/${STYLES_FILENAME} /opt/nifi/build/nifi-ui/nifi-ui.css
  # Replace icons
  cp /opt/nifi/build/build/liquid-ui/replace/icons/* /opt/nifi/build/nifi-ui/assets/icons/

  patch ui
  replace_media ui
  copy_media ui
  mv /opt/nifi/build/nifi-ui/nifi-ui.css /opt/nifi/build/nifi-ui/${STYLES_FILENAME}
  zip_package ui
}

mkdir -p /opt/nifi/build/nifi-server
unzip_server_nar
if [[ "$NIFI_TAG" =~ ^1.* ]]; then
  patch_old_ui
else
  patch_new_ui
fi
# Pack web server
cd /opt/nifi/build/nifi-server/ && zip -r /opt/nifi/build/nifi-server/nifi-server-patched.nar * -x nifi-server.nar
