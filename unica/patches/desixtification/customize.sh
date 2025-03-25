SKIPUNZIP=1

# [
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

    # Add lib32 folder
    echo "system/lib 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    echo "system/lib u:object_r:system_lib_file:s0" >> "$WORK_DIR/configs/file_context-system"

    echo "Copying 32-bit libraries"
    cp -a --preserve=all "$SRC_DIR/unica/patches/desixtification/system/lib/"* "$WORK_DIR/system/system/lib/"

    while read -r i; do
        FILE="$(echo -n "$i"| sed "s.$WORK_DIR/system/..")"
        [ -d "$i" ] && echo "$FILE 0 0 755 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
        [ -f "$i" ] && echo "$FILE 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
        FILE="$(echo -n "$FILE" | sed 's/\./\\./g')"
        echo "/$FILE u:object_r:system_lib_file:s0" >> "$WORK_DIR/configs/file_context-system"
    done <<< "$(find "$WORK_DIR/system/system/lib")"

    # Workaround for libc++ and symlinks
    echo "/system/lib/libc\+\+\.so u:object_r:system_lib_file:s0" >> "$WORK_DIR/configs/file_context-system"
    echo "system/lib/libc.so 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    echo "system/lib/libm.so 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    echo "system/lib/libdl.so 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"
    echo "system/lib/libdl_android.so 0 0 644 capabilities=0x0" >> "$WORK_DIR/configs/fs_config-system"

    # Add 32-Bit Linkers
    echo "Adding linkers..."
    cp -a --preserve=all "$SRC_DIR/unica/patches/desixtification/system/bin/bootstrap/linker" "$WORK_DIR/system/system/bin/bootstrap"
    ln -sf "linker" "$WORK_DIR/system/system/bin/bootstrap/linker_asan"
    ln -sf "/apex/com.android.runtime/bin/linker" "$WORK_DIR/system/system/bin/linker"
    ln -sf "/apex/com.android.runtime/bin/linker" "$WORK_DIR/system/system/bin/linker_asan"

    {
        echo "/system/bin/linker u:object_r:system_linker_exec:s0"
        echo "/system/bin/linker_asan u:object_r:system_file:s0"
        echo "/system/bin/bootstrap/linker u:object_r:system_linker_exec:s0"
        echo "/system/bin/bootstrap/linker_asan u:object_r:system_file:s0"

    } >> "$WORK_DIR/configs/file_context-system"

    {
        echo "system/bin/linker 0 0 755 capabilities=0x0"
        echo "system/bin/linker_asan 0 0 755 capabilities=0x0"
        echo "system/bin/bootstrap/linker 0 0 755 capabilities=0x0"
        echo "system/bin/bootstrap/linker_asan 0 0 755 capabilities=0x0"
    } >> "$WORK_DIR/configs/fs_config-system"

    # Copy APEX files
    cp -a --preserve=all "$SRC_DIR/unica/patches/desixtification/system/apex/"* "$WORK_DIR/system/system/apex/"

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
