SKIPUNZIP=1

REMOVE_FROM_WORK_DIR()
{
    local FILE_PATH="$1"

    if [ -e "$FILE_PATH" ]; then
        local FILE
        local PARTITION
        FILE="$(echo -n "$FILE_PATH" | sed "s.$WORK_DIR/..")"
        PARTITION="$(echo -n "$FILE" | cut -d "/" -f 1)"

        echo "Debloating /$FILE"
        rm -rf "$FILE_PATH"

        [[ "$PARTITION" == "system" ]] && FILE="$(echo "$FILE" | sed 's.^system/system/.system/.')"
        FILE="$(echo -n "$FILE" | sed 's/\//\\\//g')"
        sed -i "/$FILE/d" "$WORK_DIR/configs/fs_config-$PARTITION"

        FILE="$(echo -n "$FILE" | sed 's/\./\\\\\./g')"
        sed -i "/$FILE/d" "$WORK_DIR/configs/file_context-$PARTITION"
    fi
}

SOURCE_FIRMWARE_PATH=$(echo -n "$SOURCE_FIRMWARE" | sed 's./._.g' | rev | cut -d "_" -f2- | rev)
TARGET_FIRMWARE_PATH=$(echo -n "$TARGET_FIRMWARE" | sed 's./._.g' | rev | cut -d "_" -f2- | rev)

echo "Replacing saiv blobs with stock"
if [ -d "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/etc/saiv" ]; then
    BLOBS_LIST="
    /system/system/etc/saiv/image_understanding/db/aic_classifier/aic_classifier_cnn.info
    /system/system/etc/saiv/image_understanding/db/aic_detector/aic_detector_cnn.info
    "
    for blob in $BLOBS_LIST
    do
        cp -a --preserve=all "$FW_DIR/$TARGET_FIRMWARE_PATH$blob" "$WORK_DIR$blob"
    done
else
    REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/etc/saiv"
fi
REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/saiv"
cp -a --preserve=all "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/saiv" "$WORK_DIR/system/system/saiv"
REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/saiv/textrecognition"
cp -a --preserve=all "$FW_DIR/$SOURCE_FIRMWARE_PATH/system/system/saiv/textrecognition" "$WORK_DIR/system/system/saiv/textrecognition"
REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/saiv/face"
cp -a --preserve=all "$FW_DIR/$SOURCE_FIRMWARE_PATH/system/system/saiv/face" "$WORK_DIR/system/system/saiv/face"
while read -r i; do
    FILE="$(echo -n "$i"| sed "s.$WORK_DIR/system/..")"
    [ -d "$i" ] && echo "$FILE 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    [ -f "$i" ] && echo "$FILE 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    FILE="$(echo -n "$FILE" | sed 's/\./\\./g')"
    echo "/$FILE u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
done <<< "$(find "$WORK_DIR/system/system/saiv")"

echo "Replacing cameradata blobs with stock"
REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/cameradata"
cp -a --preserve=all "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/cameradata" "$WORK_DIR/system/system/cameradata"
while read -r i; do
    FILE="$(echo -n "$i"| sed "s.$WORK_DIR/system/..")"
    [ -d "$i" ] && echo "$FILE 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    [ -f "$i" ] && echo "$FILE 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    FILE="$(echo -n "$FILE" | sed 's/\./\\./g')"
    echo "/$FILE u:object_r:system_file:s0" >> "$WORK_DIR/configs/file_context-system"
done <<< "$(find "$WORK_DIR/system/system/cameradata")"

if [ -f "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/usr/share/alsa/alsa.conf" ]; then
    echo "Add stock alsa.conf"
    mkdir -p "$WORK_DIR/system/system/usr/share/alsa"
    cp -a --preserve=all "$FW_DIR/$TARGET_FIRMWARE_PATH/system/system/usr/share/alsa/alsa.conf" \
        "$WORK_DIR/system/system/usr/share/alsa/alsa.conf"
    if ! grep -q "alsa\.conf" "$WORK_DIR/configs/file_context-system"; then
        {
            echo "/system/usr/share/alsa u:object_r:system_file:s0"
            echo "/system/usr/share/alsa/alsa\.conf u:object_r:system_file:s0"
        } >> "$WORK_DIR/configs/file_context-system"
    fi
    if ! grep -q "alsa.conf" "$WORK_DIR/configs/fs_config-system"; then
        {
            echo "system/usr/share/alsa 0 0 755 capabilities=0x0"
            echo "system/usr/share/alsa/alsa.conf 0 0 644 capabilities=0x0"
        } >> "$WORK_DIR/configs/fs_config-system"
    fi
else
    REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/usr/share/alsa"
fi
