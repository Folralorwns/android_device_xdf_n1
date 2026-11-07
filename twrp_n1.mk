$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, $(LOCAL_PATH)/device.mk)

PRODUCT_DEVICE := n1
PRODUCT_NAME := twrp_n1
PRODUCT_BRAND := XDF
PRODUCT_MODEL := XDF-N1
PRODUCT_MANUFACTURER := XDF
PRODUCT_RELEASE_NAME := n1
PRODUCT_SHIPPING_API_LEVEL := 29
