SKIPUNZIP=1

echo "Fix MIDAS model detection"
sed -i "s/ro.product.device/ro.product.vendor.device/g" "$WORK_DIR/vendor/etc/midas/midas_config.json"

echo "Setting casefold props"
SET_PROP "external_storage.projid.enabled" "1" "$WORK_DIR/vendor/build.prop"
SET_PROP "external_storage.casefold.enabled" "1" "$WORK_DIR/vendor/build.prop"
SET_PROP "external_storage.sdcardfs.enabled" "0" "$WORK_DIR/vendor/build.prop"
