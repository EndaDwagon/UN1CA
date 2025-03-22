SKIPUNZIP=1

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
        sed -i "/$FILE/d" "$WORK_DIR/configs/fs_config-$PARTITION"

        FILE="$(echo -n "$FILE" | sed 's/\./\\\\\./g')"
        sed -i "/$FILE/d" "$WORK_DIR/configs/file_context-$PARTITION"
    fi
}

SET_PROP()
{
    local PROP="$1"
    local VALUE="$2"
    local FILE="$3"

    if [ ! -f "$FILE" ]; then
        echo "File not found: $FILE"
        return 1
    fi

    if [[ "$2" == "-d" ]] || [[ "$2" == "--delete" ]]; then
        PROP="$(echo -n "$PROP" | sed 's/=//g')"
        if grep -Fq "$PROP" "$FILE"; then
            echo "Deleting \"$PROP\" prop in $FILE" | sed "s.$WORK_DIR..g"
            sed -i "/^$PROP/d" "$FILE"
        fi
    else
        if grep -Fq "$PROP" "$FILE"; then
            local LINES

            echo "Replacing \"$PROP\" prop with \"$VALUE\" in $FILE" | sed "s.$WORK_DIR..g"
            LINES="$(sed -n "/^${PROP}\b/=" "$FILE")"
            for l in $LINES; do
                sed -i "$l c${PROP}=${VALUE}" "$FILE"
            done
        else
            echo "Adding \"$PROP\" prop with \"$VALUE\" in $FILE" | sed "s.$WORK_DIR..g"
            if ! grep -q "Added by scripts" "$FILE"; then
                echo "# Added by scripts/internal/apply_modules.sh" >> "$FILE"
            fi
            echo "$PROP=$VALUE" >> "$FILE"
        fi
    fi
}
# ]

MODEL=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 1)
REGION=$(echo -n "$TARGET_FIRMWARE" | cut -d "/" -f 2)

if [ -f "$FW_DIR/${MODEL}_${REGION}/vendor/lib/libdrm.so" ] ||
   [ -f "$FW_DIR/${MODEL}_${REGION}/vendor/lib/hw/android.hardware.drm@1.0-impl.so" ]; then
    echo "Target device with 32-Bit HALs detected! Patching..."

    IFS=':' read -a TARGET_EXTRA_FIRMWARES <<< "$TARGET_EXTRA_FIRMWARES"
    MODEL=$(echo -n "${TARGET_EXTRA_FIRMWARES[0]}" | cut -d "/" -f 1)
    REGION=$(echo -n "${TARGET_EXTRA_FIRMWARES[0]}" | cut -d "/" -f 2)

    # Add lib32 folder
    echo "system/lib 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    echo "system/lib u:object_r:system_lib_file:s0" >> "$WORK_DIR/configs/file_context-system"

    echo "Copying all 32-bit libraries"
    cp -a --preserve=all "$FW_DIR/${MODEL}_${REGION}/system/system/lib/"* "$WORK_DIR/system/system/lib"
    cat "$FW_DIR/${MODEL}_${REGION}/fs_config-system" | grep -F "system/lib/" >> "$WORK_DIR/configs/fs_config-system"
    cat "$FW_DIR/${MODEL}_${REGION}/file_context-system" | grep -F "system/lib/" >> "$WORK_DIR/configs/file_context-system"

    # Add 32-Bit Linkers
    echo "Adding linkers..."
    ADD_TO_WORK_DIR "system" "system/bin/linker" 0 2000 755 "u:object_r:system_linker_exec:s0"
    ADD_TO_WORK_DIR "system" "system/bin/linker_asan" 0 2000 755 "u:object_r:system_file:s0"
    ADD_TO_WORK_DIR "system" "system/bin/bootstrap/linker" 0 2000 755 "u:object_r:system_linker_exec:s0"
    ADD_TO_WORK_DIR "system" "system/bin/bootstrap/linker_asan" 0 2000 755 "u:object_r:system_file:s0"

    # Add AOSP Runtime APEX
    cp -a --preserve=all "$SRC_DIR/unica/patches/desixtification/system/apex/com.android.runtime.apex" "$WORK_DIR/system/system/apex"

    # Add i18n APEX
    ADD_TO_WORK_DIR "system" "system/apex/com.android.i18n.apex" 0 0 644 "u:object_r:system_file:s0"

    # Add tzdata5 APEX as OneUI 6 i18n APEX uses it
    REMOVE_FROM_WORK_DIR "$WORK_DIR/system/system/apex/com.google.android.tzdata6.apex"
    ADD_TO_WORK_DIR "system" "system/apex/com.google.android.tzdata5.apex" 0 0 644 "u:object_r:system_file:s0"

    # Downgrade libengmode
    ADD_TO_WORK_DIR "system" "system/lib64/lib.engmode.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "system" "system/lib64/lib.engmodejni.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"

    # Add missing camera blobs
    ADD_TO_WORK_DIR "system" "system/lib64/libtensorflowLite.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "system" "system/lib64/libtensorflowlite_c.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "system" "system/lib64/libtensorflowlite_c.spenocr.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "system" "system/lib64/libtensorflowlite_inference_api.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "system" "system/lib64/libtensorflowLite2_11_0_dynamic_camera.so" 0 0 644 "u:object_r:system_lib_file:s0"
    ADD_TO_WORK_DIR "system" "system/lib64/libsaiv_HprFace_cmh_support_jni.camera.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0"

    # Set props
    echo "Setting props..."
    SET_PROP "ro.vendor.product.cpu.abilist" "arm64-v8a" "$WORK_DIR/vendor/build.prop"
    SET_PROP "ro.vendor.product.cpu.abilist32" "" "$WORK_DIR/vendor/build.prop"
    SET_PROP "ro.vendor.product.cpu.abilist64" "arm64-v8a" "$WORK_DIR/vendor/build.prop"
    SET_PROP "ro.zygote" "zygote64" "$WORK_DIR/vendor/build.prop"
    SET_PROP "dalvik.vm.dex2oat64.enabled" "true" "$WORK_DIR/vendor/build.prop"

else
    echo "Target device does not use 32-Bit HALs. Ignoring"
fi
