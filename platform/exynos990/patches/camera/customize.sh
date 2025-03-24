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

        if [[ "$PARTITION" == "system" ]] && [[ "$FILE" == *".camera.samsung.so" ]]; then
            sed -i "/$(basename "$FILE")/d" "$WORK_DIR/system/system/etc/public.libraries-camera.samsung.txt"
        fi
        if [[ "$PARTITION" == "system" ]] && [[ "$FILE" == *".arcsoft.so" ]]; then
            sed -i "/$(basename "$FILE")/d" "$WORK_DIR/system/system/etc/public.libraries-arcsoft.txt"
        fi
        if [[ "$PARTITION" == "system" ]] && [[ "$FILE" == *".media.samsung.so" ]]; then
            sed -i "/$(basename "$FILE")/d" "$WORK_DIR/system/system/etc/public.libraries-media.samsung.txt"
        fi

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

BLOBS_LIST="
system/lib64/libpic_best.arcsoft.so
system/lib64/libdualcam_portraitlighting_gallery_360.so
system/lib64/libarcsoft_dualcam_portraitlighting.so
system/lib64/libdualcam_refocus_gallery_54.so
system/lib64/libdualcam_refocus_gallery_50.so
system/lib64/libsuper_fusion.arcsoft.so
system/lib64/libdualcam_refocus_image_lite.so
system/lib64/libhybrid_high_dynamic_range.arcsoft.so
system/lib64/libae_bracket_hdr.arcsoft.so
system/lib64/libface_recognition.arcsoft.so
system/lib64/libmf_bayer_enhance.arcsoft.so
system/lib64/libDualCamBokehCapture.camera.samsung.so
"
for blob in $BLOBS_LIST
do
    REMOVE_FROM_WORK_DIR "$WORK_DIR/system/$blob"
done

echo "Add stock camera libs"
BLOBS_LIST="
system/lib64/libMultiFrameProcessing20.camera.samsung.so
system/lib64/libMultiFrameProcessing20Core.camera.samsung.so
system/lib64/libMultiFrameProcessing20Day.camera.samsung.so
system/lib64/libMultiFrameProcessing20Tuning.camera.samsung.so
system/lib64/libMultiFrameProcessing30.camera.samsung.so
system/lib64/libMultiFrameProcessing30.snapwrapper.camera.samsung.so
system/lib64/libMultiFrameProcessing30Tuning.camera.samsung.so
system/lib64/libGeoTrans10.so
system/lib64/vendor.samsung_slsi.hardware.geoTransService@1.0.so
system/lib64/libSwIsp_core.camera.samsung.so
system/lib64/libSwIsp_wrapper_v1.camera.samsung.so
"

for blob in $BLOBS_LIST
do
    ADD_TO_WORK_DIR "system" "$blob" 0 0 644 "u:object_r:system_lib_file:s0"
done

# Add libc++_shared.so dependency for __cxa_demangle symbol
patchelf --add-needed "libc++_shared.so" "$WORK_DIR/system/system/lib64/libMultiFrameProcessing20Core.camera.samsung.so"

if ! grep -q "libeden_wrapper_system" "$WORK_DIR/configs/file_context-system"; then
    {
        echo "/system/lib64/libc\+\+_shared\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libeden_wrapper_system\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libhigh_dynamic_range\.arcsoft\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/liblow_light_hdr\.arcsoft\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libsuperresolution\.arcsoft\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libsuperresolution_raw\.arcsoft\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libsuperresolution_wrapper_v2\.camera\.samsung\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libsuperresolutionraw_wrapper_v2\.camera\.samsung\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libtensorflowLite\.camera\.samsung\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libtensorflowlite_c\.camera\.samsung\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libtensorflowlite_inference_api\.camera\.samsung\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libtensorflowlite_jni_voicecommand\.camera\.samsung\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libtensorflowLite2_11_0_dynamic_camera\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/libsaiv_HprFace_cmh_support_jni\.camera\.samsung\.so u:object_r:system_lib_file:s0"
        echo "/system/lib64/vendor\.samsung\.hardware\.snap-V2-ndk\.so u:object_r:system_lib_file:s0"

    } >> "$WORK_DIR/configs/file_context-system"
fi
if ! grep -q "libeden_wrapper_system" "$WORK_DIR/configs/fs_config-system"; then
    {
        echo "system/lib64/libc++_shared.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libeden_wrapper_system.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libhigh_dynamic_range.arcsoft.so 0 0 644 capabilities=0x0"
        echo "system/lib64/liblow_light_hdr.arcsoft.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libsuperresolution.arcsoft.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libsuperresolution_raw.arcsoft.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libsuperresolution_wrapper_v2.camera.samsung.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libsuperresolutionraw_wrapper_v2.camera.samsung.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libtensorflowLite.camera.samsung.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libtensorflowlite_c.camera.samsung.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libtensorflowlite_inference_api.camera.samsung.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libtensorflowlite_jni_voicecommand.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libtensorflowLite2_11_0_dynamic_camera.so 0 0 644 capabilities=0x0"
        echo "system/lib64/libsaiv_HprFace_cmh_support_jni.camera.samsung.so 0 0 644 capabilities=0x0"
        echo "system/lib64/vendor.samsung.hardware.snap-V2-ndk.so 0 0 644 capabilities=0x0"
    } >> "$WORK_DIR/configs/fs_config-system"
fi