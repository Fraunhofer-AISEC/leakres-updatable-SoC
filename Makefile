###############################################################################
# Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V. 
# acting on behalf of its Fraunhofer Institute AISEC. 
# All rights reserved.
###############################################################################

base_dir = $(abspath .)

# User configuration - hardware (zedboardRevD / zc702)
# -----------------------------------------------------------------------------
BOARD = zedboardRevD

# User configuration - project
# -----------------------------------------------------------------------------
CONFIG = SEC_UP_DEMO

# Build Target  (WIN, Default)
# -----------------------------------------------------------------------------
#TARGET = WIN

# Other configurations
# -----------------------------------------------------------------------------
UBOOT_GIT_REP = https://github.com/Xilinx/u-boot-xlnx.git
UBOOT_DIR = u-boot-xlnx
BINARIES_OUTPUT_DIR = images
PRODUCTS_OUTPUT_DIR = sdcard
TESTCASES_DIR=src/lr-aes

# User configuration - AES-GCM parameters for partial bitfile encryption
# -----------------------------------------------------------------------------
# Block length (in Bytes, must be a multiple of 16; range 16...4096)
LR_AES_BLOCK_LENGTH = 4096
# LR AES encryption python script
LR_AES_PY_SCRIPT = ./src/lr-aes/ui-lrprf_ofb_gmac.py
# LR AES IV dir
LR_AES_IV_DIR = ./src/lr-aes/iv
#LR AES AAD dir
LR_AES_AAD_DIR = ./src/lr-aes/aad

# hardware configuration
# -----------------------------------------------------------------------------
ifeq ($(BOARD), zedboardRevD)
	BOARD_MODEL = em.avnet.com:zed:part0:1.2
	PART = xc7z020clg484-1
	VIVADO_VER = 2017.2
	UBOOT_TAG = xilinx-v2016.3
	UBOOT_CONFIG = zynq_zed_config
	ZYNQ_CONFIG = ZedBoard
else ifeq ($(BOARD), zc702)
	BOARD_MODEL = xilinx.com:zc702:part0:1.0
	PART = xc7z020clg484-1
	VIVADO_VER = 2017.2
	UBOOT_TAG = xilinx-v2016.3
	UBOOT_CONFIG = zynq_zc702_config
	ZYNQ_CONFIG = ZC702
else
	BOARD_MODEL = em.avnet.com:zed:part0:1.2
	PART = xc7z020clg484-1
	VIVADO_VER = 2017.2
	UBOOT_TAG = xilinx-v2016.3
	UBOOT_CONFIG = zynq_zed_config
	ZYNQ_CONFIG = ZedBoard
endif

# project configuration
# -----------------------------------------------------------------------------

PROJ_NAME =sec_boot
IP_NAME = lr_aes_ofb_gmac
IP_CORE = LRAES_OFB_GMAC
#IP_CORE = LRAEAD_STREAMCIPHER
IP_TYPE0 = crypto_cores


default: all

all: key-enroll
key-enroll: ip hard enroll
key-reproduction: soft post


# Build hardware
# -----------------------------------------------------------------------------
hard: project bitstream export-hdf

# AXI IP packaging
# ------------------------------------------------------------------------------

# Set up AXI IP core
ip: lraead-axi led-driver-axi pr-ctrl-axi lraead-streamcipher-axi puf-axi

# LRAES OFB GMAC IP packaging Creates,patch and package
# ------------------------------------------------------------------------------
lraead-axi:
	[ -d ip_repo ] && echo "Directory checkpoints Exists" || mkdir ip_repo
	vivado -mode batch -notrace -source src/ip_repo/lr_aes_ofb_gmac_1.0/tcl/create_axi_ip.tcl -tclargs $(BOARD_MODEL) $(PART) $(IP_NAME) $(IP_TYPE0) $(PROJ_NAME);
	patch ip_repo/lr_aes_ofb_gmac_1.0/hdl/lr_aes_ofb_gmac_v1_0.vhd src/ip_repo/lr_aes_ofb_gmac_1.0/lr_aes_ofb_gmac_v1_0.vhd.patch
	patch ip_repo/lr_aes_ofb_gmac_1.0/hdl/lr_aes_ofb_gmac_v1_0_S00_AXI.vhd src/ip_repo/lr_aes_ofb_gmac_1.0/lr_aes_ofb_gmac_v1_0_S00_AXI.vhd.patch
	vivado -mode batch -notrace -source src/ip_repo/lr_aes_ofb_gmac_1.0/tcl/edit_ip.tcl -tclargs $(PROJ_NAME) $(IP_NAME);

# LRAEAD Streamcipher IP packaging Creates,patch and package
# ------------------------------------------------------------------------------
IP0_NAME= lraead_streamcipher
lraead-streamcipher-axi:
	[ -d ip_repo ] && echo "Directory checkpoints Exists" || mkdir ip_repo
	vivado -mode batch -notrace -source src/ip_repo/lraead_streamcipher/tcl/create_axi_ip.tcl -tclargs $(BOARD_MODEL) $(PART) $(IP0_NAME) $(IP_TYPE0) $(PROJ_NAME);
	patch ip_repo/lraead_streamcipher_1.0/hdl/lraead_streamcipher_v1_0.vhd src/ip_repo/lraead_streamcipher/lraead_streamcipher_v1_0.vhd.patch
	patch ip_repo/lraead_streamcipher_1.0/hdl/lraead_streamcipher_v1_0_S00_AXI.vhd src/ip_repo/lraead_streamcipher/lraead_streamcipher_v1_0_S00_AXI.vhd.patch
	vivado -mode batch -notrace -source src/ip_repo/lraead_streamcipher/tcl/edit_ip.tcl -tclargs $(PROJ_NAME) $(IP0_NAME);

# LED Driver IP packaging Creates,patch and package
# ------------------------------------------------------------------------------
IP1_NAME = led_driver_axi
IP_TYPE2 = misc
led-driver-axi:
	[ -d ip_repo ] && echo "Directory checkpoints Exists" || mkdir ip_repo
	vivado -mode batch -notrace -source src/ip_repo/led_driver/tcl/create_axi_ip.tcl -tclargs $(BOARD_MODEL) $(PART) $(IP1_NAME) $(IP_TYPE2) $(PROJ_NAME);
	patch ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0.vhd src/ip_repo/led_driver/led_driver_axi_wrapper.vhd.patch
	patch ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0_S00_AXI.vhd src/ip_repo/led_driver/led_driver_axi.vhd.patch
	vivado -mode batch -notrace -source src/ip_repo/led_driver/tcl/edit_ip.tcl -tclargs $(PROJ_NAME) $(IP1_NAME) $(GROUP_NAME);
	cp ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0.vhd ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0_Config01.vhd
	cp ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0.vhd ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0_Config02.vhd
	patch ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0_Config01.vhd src/ip_repo/led_driver/led_driver_v1_0_Config01.vhd.patch
	patch ip_repo/led_driver_axi_1.0/hdl/led_driver_axi_v1_0_Config02.vhd src/ip_repo/led_driver/led_driver_v1_0_Config02.vhd.patch;

# PR Controller IP packaging Creates,patch and package
# ------------------------------------------------------------------------------
IP2_NAME = pr_controller
IP_TYPE1 = configuration

pr-ctrl-axi:
	[ -d ip_repo ] && echo "Directory checkpoints Exists" || mkdir ip_repo
	vivado -mode batch -notrace -source src/ip_repo/pr_controller/tcl/create_axi_ip.tcl -tclargs $(BOARD_MODEL) $(PART) $(IP2_NAME) $(IP_TYPE1) $(PROJ_NAME)
	patch ip_repo/pr_controller_1.0/hdl/pr_controller_v1_0.vhd src/ip_repo/pr_controller/pr_controller_v1_0.vhd.patch
	patch ip_repo/pr_controller_1.0/hdl/pr_controller_v1_0_S00_AXI.vhd src/ip_repo/pr_controller/pr_controller_v1_0_S00_AXI.vhd.patch
	vivado -mode batch -notrace -source src/ip_repo/pr_controller/tcl/edit_ip.tcl -tclargs $(PROJ_NAME) $(IP2_NAME) $(IP_TYPE1);
# PUF IP packaging Creates,patch and package
# ------------------------------------------------------------------------------
puf-axi:
	git submodule init
	git submodule update --init --recursive
	cd ./ip_repo/fuzzy-key-commit.git ;\
	make ip ;\

# Clean IP Repo
#-------------------------------------------------------------------------------
clean-ip:
	rm -rf ip_repo/led_driver_axi_1.0/
	rm -rf ip_repo/lraead_streamcipher_1.0/
	rm -rf ip_repo/lr_aes_ofb_gmac_1.0/
	rm -rf ip_repo/pr_controller_1.0/



PROJ_NAME = $(BOARD)_$(CONFIG)

# Hardware generation
# ------------------------------------------------------------------------------

# Set up vivado project
project:
	[ -d checkpoints ] && echo "Directory checkpoints Exists" || mkdir checkpoints
	vivado -mode batch -notrace -source project_creation.tcl -tclargs $(BOARD_MODEL) $(PART) $(PROJ_NAME) $(VIVADO_VER) $(ZYNQ_CONFIG) $(LR_AES_BLOCK_LENGTH) $(IP_CORE);

# Opens vivado project in GUI
vivado:
	vivado vivado_project/$(PROJ_NAME).xpr &

# Generates the PL bitstream
bitstream:
	[ -d checkpoints ] && echo "Directory checkpoints Exists" || mkdir checkpoints
	[ -d ./$(BINARIES_OUTPUT_DIR) ] && echo "Directory ./$(BINARIES_OUTPUT_DIR) Exists" || mkdir ./$(BINARIES_OUTPUT_DIR)
	[ -d ./$(PRODUCTS_OUTPUT_DIR) ] && echo "Directory ./$(PRODUCTS_OUTPUT_DIR) Exists" || mkdir ./$(PRODUCTS_OUTPUT_DIR)
	vivado -mode tcl -source src/tcl/make_bitstream.tcl -tclargs $(PROJ_NAME) $(PART)

# Exports the hardware definition file to xsdk project
export-hdf:
	vivado -mode batch -source src/tcl/export_hdf.tcl -tclargs $(PROJ_NAME);

# Key Enrollment
# --------------------------------------------------
enroll: puf-enroll boot-enroll
puf-enroll:
	vivado -mode tcl -source src/tcl/export_sdk.tcl -tclargs $(PROJ_NAME)
	xsdk -batch -source src/tcl/make_firmware_enroll.tcl $(PROJ_NAME)
	cp ./vivado_project/$(PROJ_NAME).sdk/fsbl/Debug/fsbl.elf ./$(BINARIES_OUTPUT_DIR)/
	cp ./vivado_project/$(PROJ_NAME).sdk/key_enroll/Debug/key_enroll.elf ./$(BINARIES_OUTPUT_DIR)/

# Software generation - FSBL and U-Boot
# ------------------------------------------------------------------------------

soft:  fsbl fsbl-copy-binaries uboot-src patch-uboot uboot-build uboot-copy-binaries

# Board Support Package / First Stage Boot Loader
# TODO: Uncomment patch when PUF is used to trigger key reproduction instead of hard-coded key for testing
fsbl:
	rm -rf ./vivado_project/$(PROJ_NAME).sdk
	vivado -mode tcl -source src/tcl/export_sdk.tcl -tclargs $(PROJ_NAME)
	xsdk -batch -source src/tcl/make_firmware.tcl $(PROJ_NAME)
	patch vivado_project/zedboardRevD_SEC_UP_DEMO.sdk/fsbl/src/main.c src/fsbl/main.patch
	xsdk -batch -source src/tcl/build_firmware.tcl $(PROJ_NAME)

fsbl-copy-binaries:
	cp ./vivado_project/$(PROJ_NAME).sdk/fsbl/Debug/fsbl.elf ./$(BINARIES_OUTPUT_DIR)/


# Download uboot sources based on target
uboot-src: git-clone-uboot

# GIT repository download

git-clone-uboot:
	git clone $(UBOOT_GIT_REP)
	cd $(UBOOT_DIR); git checkout tags/$(UBOOT_TAG)

# Copies the U-Boot command- and driver sources into to the project
patch-uboot:
	patch $(UBOOT_DIR)/cmd/Makefile ./src/uboot/$(UBOOT_TAG)/patch_files/cmd/Makefile.patch
	patch $(UBOOT_DIR)/drivers/Makefile ./src/uboot/$(UBOOT_TAG)/patch_files/drivers/Makefile.patch
	patch $(UBOOT_DIR)/include/configs/zynq-common.h ./src/uboot/$(UBOOT_TAG)/patch_files/zynq-common.h.patch
	cp -r ./src/uboot/$(UBOOT_TAG)/src_files/* $(UBOOT_DIR)/

# Delete the U-Boot sources
remove-uboot:
	rm -rf ./$(UBOOT_DIR)

# U-Boot
uboot-build:
	cd $(UBOOT_DIR); export CROSS_COMPILE=arm-xilinx-linux-gnueabi-; export ARCH=arm; make $(UBOOT_CONFIG);
	cd $(UBOOT_DIR); export CROSS_COMPILE=arm-xilinx-linux-gnueabi-; export ARCH=arm; make

uboot-copy-binaries:
	cp -f ./$(UBOOT_DIR)/u-boot ./$(BINARIES_OUTPUT_DIR)/u-boot.elf

# U-Boot
uboot-clean:
	cd $(UBOOT_DIR); make clean;


# post build
# ------------------------------------------------------------------------------

post: boot-bin encrypt-bitstreams

# creates a unencrypted boot.bin
boot-bin:
	[ -d ./$(PRODUCTS_OUTPUT_DIR) ] && echo "Directory ./$(PRODUCTS_OUTPUT_DIR) Exists" || mkdir ./$(PRODUCTS_OUTPUT_DIR)
	bootgen -image src/boot.bif -o $(PRODUCTS_OUTPUT_DIR)/BOOT.BIN -w
# creates a unencrypted boot.bin
boot-enroll:
	[ -d ./$(PRODUCTS_OUTPUT_DIR) ] && echo "Directory ./$(PRODUCTS_OUTPUT_DIR) Exists" || mkdir ./$(PRODUCTS_OUTPUT_DIR)
	bootgen -image src/boot_enroll.bif -o $(PRODUCTS_OUTPUT_DIR)/BOOT_enroll.BIN -w


# Encrypt partial reconfigurations (LR AES)
# -------------------------------------------------------------------------------
LR_AES_PY_PARAMS += --key0=$(PRODUCTS_OUTPUT_DIR)/key_file0.txt
LR_AES_PY_PARAMS += --key1=$(PRODUCTS_OUTPUT_DIR)/key_file1.txt
LR_AES_PY_PARAMS += --bl=$(LR_AES_BLOCK_LENGTH)
LR_AES_PY_PARAMS += --force

encrypt-bitstreams:
ifeq ($(IP_CORE),LRAES_OFB_GMAC)
	python3 $(LR_AES_PY_SCRIPT) $(LR_AES_PY_PARAMS) --iv=$(LR_AES_IV_DIR)/iv0.txt --aad=$(LR_AES_AAD_DIR)/aad0.bin --ptxt=$(BINARIES_OUTPUT_DIR)/p_blank.bin --ctxt=$(PRODUCTS_OUTPUT_DIR)/p_blank_enc.bin
	python3 $(LR_AES_PY_SCRIPT) $(LR_AES_PY_PARAMS) --iv=$(LR_AES_IV_DIR)/iv1.txt --aad=$(LR_AES_AAD_DIR)/aad1.bin --ptxt=$(BINARIES_OUTPUT_DIR)/p_c00.bin --ctxt=$(PRODUCTS_OUTPUT_DIR)/p_c00_enc.bin
	python3 $(LR_AES_PY_SCRIPT) $(LR_AES_PY_PARAMS) --iv=$(LR_AES_IV_DIR)/iv2.txt --aad=$(LR_AES_AAD_DIR)/aad2.bin --ptxt=$(BINARIES_OUTPUT_DIR)/p_c01.bin --ctxt=$(PRODUCTS_OUTPUT_DIR)/p_c01_enc.bin
	python3 $(LR_AES_PY_SCRIPT) $(LR_AES_PY_PARAMS) --iv=$(LR_AES_IV_DIR)/iv3.txt --aad=$(LR_AES_AAD_DIR)/aad3.bin --ptxt=$(BINARIES_OUTPUT_DIR)/p_c02.bin --ctxt=$(PRODUCTS_OUTPUT_DIR)/p_c02_enc.bin

else ifeq ($(IP_CORE),LRAEAD_STREAMCIPHER)
	$(info encryption script can be found at src/src/leakres-aead-host/)
	$(info build instructions can be found in src/leakres-aead-host/Readme.md)
	$(info Usage: ./tests/lraead_test <aadfile.bin> <images/p_c01.bin> <keys.bin> <nonce.bin> <sdcards/p_c00_enc.bin>)
endif

# clean project
# -------------------------------------------------------------------------------

clean:	clean-soft clean-hw clean-images

# Clean software
clean-soft: remove-uboot
	rm -rf vivado_project/$(PROJ_NAME).sdk/

clean-images:
ifeq ($(OS),Windows_NT)
		rm -f ./images/*.bit
		rm -f ./images/*.prm
		rm -f ./images/*.bin
		rm -f ./images/f_init
		rm -f ./images/fsbl.elf
else
		find ./images -type f -not -name 'u-boot.elf' -delete
endif

clean-sdcard:
	rm -rf ./sdcard/*

# Clean hardware files
clean-hw: 
	- rm -f *.log *.jou *.str
	- rm -rf src/bd/zynq_design
	- rm -rf vivado_project
	- rm -rf checkpoints/
	- rm -rf .Xil
	- rm -f *_webtalk.html
	- rm -f *_webtalk.xml
.PHONY: project vivado bitstream export-hdf patch-uboot copy-images boot-bin boot-bin-enc copy-sdcard clean-soft clean-sdcard clean-hw ip lraead-axi led-driver-axi pr-ctrl-axi lraead-streamcipher-axi puf-axi

