if { $argc != 2 } {
    puts "The script requires  two inputs. PROJ_NAME, PART"
	puts "Set to default values for zedboard"
	set PROJ_NAME "project_1"
	set PART "xc7z020clg484-1"
	} else {
	set PROJ_NAME [lindex $argv 0]
	set PART [lindex $argv 1]
	}

################################################################
######                  SYNTHESIZE DESIGN                 ######
################################################################

open_project vivado_project/$PROJ_NAME.xpr
reset_run synth_1
reset_run impl_1
launch_runs synth_1
wait_on_run synth_1

open_run synth_1 -name synth_1


################################################################
######                  WRITE CHECKPOINT                  ######
################################################################

set partialCell_00 "zynq_design_i/led_driver_axi_0"

# black box all reconfigurable partitions
update_design -cell $partialCell_00 -black_box

# save checkpoint
write_checkpoint ./checkpoints/netlist_static_only.dcp -force

close_project

################################################################
######                 SYNTHESIZE PARTIALS                ######
################################################################


################## ledDriver config 00 #########################

set wrapperModuleName "led_driver_axi_wrapper"
set hdlDir "./ip_repo/led_driver_axi_1.0/hdl/"
set dcpOutputDir "./checkpoints/"
set module00FileName "led_driver_axi_v1_0_S00_AXI.vhd"

set wrapperFileName "led_driver_axi_v1_0"
set wrapperFileType ".vhd"
set dcpOutputFileName "ledDriver_partConf_00"

read_vhdl $hdlDir$wrapperFileName$wrapperFileType
read_vhdl $hdlDir$module00FileName
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

synth_design -mode out_of_context -flatten_hierarchy rebuilt -top $wrapperModuleName -part $PART
write_checkpoint -force $dcpOutputDir$dcpOutputFileName.dcp

close_design
# close project to remove all files from the project
close_project

################## ledDriver config 01 #########################

set wrapperFileName "led_driver_axi_v1_0_Config01"
set wrapperFileType ".vhd"
set dcpOutputFileName "ledDriver_partConf_01"

read_vhdl $hdlDir$wrapperFileName$wrapperFileType
read_vhdl $hdlDir$module00FileName
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

synth_design -mode out_of_context -flatten_hierarchy rebuilt -top $wrapperModuleName -part $PART
write_checkpoint -force $dcpOutputDir$dcpOutputFileName.dcp

close_design
close_project

################## ledDriver config 02 #########################

set wrapperFileName "led_driver_axi_v1_0_Config02"
set wrapperFileType ".vhd"
set dcpOutputFileName "ledDriver_partConf_02"

read_vhdl $hdlDir$wrapperFileName$wrapperFileType
read_vhdl $hdlDir$module00FileName
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

synth_design -mode out_of_context -flatten_hierarchy rebuilt -top $wrapperModuleName -part $PART
write_checkpoint -force $dcpOutputDir$dcpOutputFileName.dcp

close_design
close_project


################################################################
######                   IMPLEMENTATION                   ######
################################################################

############## preparation of the static design ################


# open synthesized static design (without partial modules)
open_checkpoint ./checkpoints/netlist_static_only.dcp

# read initial configurations (biggest)
read_checkpoint -cell $partialCell_00 ./checkpoints/ledDriver_partConf_00.dcp

# define all reconfigurable partitions as reconfigurable
set_property HD.RECONFIGURABLE 1 [get_cells $partialCell_00]

# floorplan the reconfigurable partitions
create_pblock pblock_pr_ledDriver
add_cells_to_pblock [get_pblocks pblock_pr_ledDriver] [get_cells $partialCell_00]
# to use the RESET_AFTER_RECONFIG-feature, the reconfigurable partition
# must align to the top and bottom of a clock region
resize_pblock pblock_pr_ledDriver -add SLICE_X94Y0:SLICE_X101Y49
# enable the reset after reconfiguration
set_property RESET_AFTER_RECONFIG 1 [get_pblocks pblock_pr_ledDriver]

# run PR's design rule check
report_drc -checks [get_drc_checks HDPR*]

# implement design with partial modules
opt_design
place_design
route_design
report_utilization -hierarchical -file ./checkpoints/util_impl_conf_00.rpt

# write checkpoint of initial configuration (biggest)
write_checkpoint -force ./checkpoints/impl_conf_00.dcp

# black box all reconfigurable partitions
update_design -cell $partialCell_00 -black_box

# locks the placed and routed design 
# (subsequent opt/place/route-operations will not change the design
lock_design -level routing

# this checkpoint will be used to implement all configurations
write_checkpoint -force ./checkpoints/impl_static_only.dcp



#######################  Implementation  #######################

#### implement blank configuration ####

# insert LUT1 buffers to the input- and outputports of the (empty) RM
update_design -buffer_ports -cell $partialCell_00

place_design
route_design
report_utilization -hierarchical -file ./checkpoints/util_impl_conf_static.rpt

# write blank configuration
write_checkpoint -force ./checkpoints/impl_conf_blank.dcp

close_project


#### implement full design with config 01 ####

# read the locked implementation of the static design
# (created at the end of 'preparation')
open_checkpoint ./checkpoints/impl_static_only.dcp

# insert next configurations in RPs
read_checkpoint -cell $partialCell_00 ./checkpoints/ledDriver_partConf_01.dcp

# implement
opt_design
place_design
route_design
report_utilization -hierarchical -file ./checkpoints/util_impl_conf_01.rpt

# save the configuration
write_checkpoint -force ./checkpoints/impl_conf_01.dcp

close_project


#### implement full design with config 02 ####

# read the locked implementation of the static design
# (created at the end of 'preparation')
open_checkpoint ./checkpoints/impl_static_only.dcp

# insert next configurations in RPs
read_checkpoint -cell $partialCell_00 ./checkpoints/ledDriver_partConf_02.dcp

#implement
opt_design
place_design
route_design

# save the configuration
write_checkpoint -force ./checkpoints/impl_conf_02.dcp

close_project


####################### verification ###########################


# additional DCPs are compared against the initial DCP
pr_verify -initial ./checkpoints/impl_conf_blank.dcp -additional {./checkpoints/impl_conf_00.dcp ./checkpoints/impl_conf_01.dcp ./checkpoints/impl_conf_02.dcp}

close_project


####################### create bitstreams ######################

#### blank ####
open_checkpoint ./checkpoints/impl_conf_blank.dcp
write_bitstream -force -file ./images/config_blank.bit
close_project


#### config 00 ####
open_checkpoint ./checkpoints/impl_conf_00.dcp
write_bitstream -force -file ./images/config_00.bit
close_project

#### config 01 ####
open_checkpoint ./checkpoints/impl_conf_01.dcp
write_bitstream -force -file ./images/config_01.bit
close_project

#### config 02 ####
open_checkpoint ./checkpoints/impl_conf_02.dcp
write_bitstream -force -file ./images/config_02.bit
close_project


######################## write binaries ########################

write_cfgmem -format BIN -interface SMAPx32 -disablebitswap -loadbit "up 0x0 images/config_00.bit" images/f_init.bin -force
write_cfgmem -format BIN -interface SMAPx32 -disablebitswap -loadbit "up 0x0 images/config_blank_pblock_pr_ledDriver_partial.bit" images/p_blank.bin -force
write_cfgmem -format BIN -interface SMAPx32 -disablebitswap -loadbit "up 0x0 images/config_00_pblock_pr_ledDriver_partial.bit" images/p_c00.bin -force
write_cfgmem -format BIN -interface SMAPx32 -disablebitswap -loadbit "up 0x0 images/config_01_pblock_pr_ledDriver_partial.bit" images/p_c01.bin -force
write_cfgmem -format BIN -interface SMAPx32 -disablebitswap -loadbit "up 0x0 images/config_02_pblock_pr_ledDriver_partial.bit" images/p_c02.bin -force

exit
