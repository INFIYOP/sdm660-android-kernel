ifneq ($(filter tulip whyred, $(TARGET_DEVICE)),)

# Prebuilt mainline kernel produced by CI (see kernel/ci/build-kernel.yml in the port repo).
# Drop Image.gz and the DTBs into shared/prebuilt-kernel/android-$(TARGET_KERNEL_USE)/.
PREBUILT_KDIR := device/generic/sdm660/shared/prebuilt-kernel/android-$(TARGET_KERNEL_USE)
IMAGE_GZ := $(PREBUILT_KDIR)/Image.gz

DTB_tulip  := $(PREBUILT_KDIR)/sdm636-xiaomi-tulip.dtb
DTB_whyred := $(PREBUILT_KDIR)/sdm636-xiaomi-whyred-tianma.dtb $(PREBUILT_KDIR)/sdm636-xiaomi-whyred-shenchao.dtb
DTB := $(DTB_$(TARGET_DEVICE))

$(PRODUCT_OUT)/kernel: $(IMAGE_GZ) $(DTB)
	cat $(IMAGE_GZ) $(DTB) > $@

droidcore: $(PRODUCT_OUT)/kernel

endif
