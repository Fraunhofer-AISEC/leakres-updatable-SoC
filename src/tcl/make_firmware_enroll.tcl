#!/usr/bin/tclsh
if { $argc != 1 } {
	    puts "The script requires one input. PROJ_NAME"
        puts "Set to default values for zedboard"
        set PROJ_NAME "zedboardRevD_PR_dummyAES"
        } else {
	        set PROJ_NAME [lindex $argv 0]
        }
puts  "make firmware-Project name: $PROJ_NAME"
sdk setws vivado_project/$PROJ_NAME.sdk
sdk createhw -name zynq_design_wrapper_hw_platform_0 -hwspec vivado_project/$PROJ_NAME.sdk/zynq_design_wrapper.hdf
sdk createapp -name fsbl -app {Zynq FSBL} -proc ps7_cortexa9_0 -hwproject zynq_design_wrapper_hw_platform_0 -os standalone -bsp fsbl_bsp

sdk projects -build -type bsp -name fsbl_bsp
# Project: PUF enrollment
sdk createapp -name key_enroll -proc ps7_cortexa9_0 -hwproject zynq_design_wrapper_hw_platform_0 -bsp standalone_bsp_0 -os standalone -lang c
file copy ip_repo/fuzzy-key-commit.git/patch/src/fuzzy_key_commitment.c vivado_project/$PROJ_NAME.sdk/key_enroll/src/
file copy ip_repo/fuzzy-key-commit.git/patch/src/fuzzy_key_commitment.h vivado_project/$PROJ_NAME.sdk/key_enroll/src/
file copy src/puf/fkc_enroll.c vivado_project/$PROJ_NAME.sdk/key_enroll/src/
file delete vivado_project/$PROJ_NAME.sdk/key_enroll/src/helloworld.c
sdk projects -build -type all

puts "finished build"
exit
