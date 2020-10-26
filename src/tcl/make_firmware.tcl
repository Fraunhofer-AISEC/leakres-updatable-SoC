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

file copy src/fsbl/fkc_reproduction.c vivado_project/$PROJ_NAME.sdk/fsbl/src
file copy ip_repo/fuzzy-key-commit.git/patch/src/fuzzy_key_commitment.c vivado_project/$PROJ_NAME.sdk/fsbl/src
file copy ip_repo/fuzzy-key-commit.git/patch/src/fuzzy_key_commitment.h vivado_project/$PROJ_NAME.sdk/fsbl/src

puts "fsbl created"
exit
