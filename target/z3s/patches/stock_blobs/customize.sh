# [
ADD_TO_WORK_DIR()
{
    local PARTITION="$1"
    local FILE_PATH="$2"
    local TMP

    case "$PARTITION" in
        "system_ext")
            if $TARGET_HAS_SYSTEM_EXT; then
                FILE_PATH="system_ext/$FILE_PATH"
            else
                PARTITION="system"
                FILE_PATH="system/system/system_ext/$FILE_PATH"
            fi
        ;;
        *)
            FILE_PATH="$PARTITION/$FILE_PATH"
            ;;
    esac

    mkdir -p "$WORK_DIR/$(dirname "$FILE_PATH")"
    cp -a --preserve=all "$FW_DIR/${MODEL}_${REGION}/$FILE_PATH" "$WORK_DIR/$FILE_PATH"

    TMP="$FILE_PATH"
    [[ "$PARTITION" == "system" ]] && TMP="$(echo "$TMP" | sed 's.^system/system/.system/.')"
    while [[ "$TMP" != "." ]]
    do
        if ! grep -q "$TMP " "$WORK_DIR/configs/fs_config-$PARTITION"; then
            if [[ "$TMP" == "$FILE_PATH" ]]; then
                echo "$TMP $3 $4 $5 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"
            elif [[ "$PARTITION" == "vendor" ]]; then
                echo "$TMP 0 2000 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"
            else
                echo "$TMP 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-$PARTITION"
            fi
        else
            break
        fi

        TMP="$(dirname "$TMP")"
    done

    TMP="$(echo "$FILE_PATH" | sed 's/\./\\\./g')"
    [[ "$PARTITION" == "system" ]] && TMP="$(echo "$TMP" | sed 's.^system/system/.system/.')"
    while [[ "$TMP" != "." ]]
    do
        if ! grep -q "/$TMP " "$WORK_DIR/configs/file_context-$PARTITION"; then
            echo "/$TMP $6" >> "$WORK_DIR/configs/file_context-$PARTITION"
        else
            break
        fi

        TMP="$(dirname "$TMP")"
    done
}

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
        sed -i "/$FILE /d" "$WORK_DIR/configs/fs_config-$PARTITION"

        FILE="$(echo -n "$FILE" | sed 's/\./\\\\\./g')"
        sed -i "/$FILE /d" "$WORK_DIR/configs/file_context-$PARTITION"
    fi
}
# ]

MODEL=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 1)
REGION=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 2)

# S25 Ultra OneUI 7 -> SoundBooster 2060
# S20 Series -> SoundBooster 1050
echo "Replacing SoundBooster"
REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/lib64/lib_SoundBooster_ver2060.so"
ADD_TO_WORK_DIR "system" "system/lib64/lib_SoundBooster_ver1050.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "system" "system/lib64/libsamsungSoundbooster_plus_legacy.so" 0 0 644 "u:object_r:system_lib_file:s0"

echo "Replacing GameDriver"
REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/priv-app/GameDriver-SM8750"
ADD_TO_WORK_DIR "system" "system/priv-app/GameDriver-EX9830/GameDriver-EX9830.apk" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "system" "system/priv-app/DevGPUDriver-EX9830/DevGPUDriver-EX9830.apk" 0 0 644 "u:object_r:system_file:s0"

echo "Replacing Hotword"
REMOVE_FROM_WORK_DIR "$WORK_DIR/product/priv-app/HotwordEnrollmentXGoogleEx6_WIDEBAND_LARGE"
REMOVE_FROM_WORK_DIR "$WORK_DIR/product/priv-app/HotwordEnrollmentYGoogleEx6_WIDEBAND_LARGE"
ADD_TO_WORK_DIR "product" "priv-app/HotwordEnrollmentOKGoogleEx3CORTEXM4/HotwordEnrollmentOKGoogleEx3CORTEXM4.apk" 0 0 644 "u:object_r:system_file:s0"
ADD_TO_WORK_DIR "product" "priv-app/HotwordEnrollmentXGoogleEx3CORTEXM4/HotwordEnrollmentXGoogleEx3CORTEXM4.apk" 0 0 644 "u:object_r:system_file:s0"
