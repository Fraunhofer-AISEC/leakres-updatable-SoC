if { $argc != 5 } {
        puts "The script requires five inputs. BOARD, PART, PROJ_NAME, IPCORE, VIVADO_VER"
	puts "Set to default values for zedboard"
	set BOARD "em.avnet.com:zed:part0:1.3"
	set PART "xc7z020clg484-1"
	set IP_NAME "test"
#	set IPCORE "AES"
	set IP_TYPE0 "hws"
	set PROJ_NAME "sec_boot"
	} else {
		set BOARD [lindex $argv 0]
	set PART [lindex $argv 1]
	set IP_NAME [lindex $argv 2]
#	set IPCORE [lindex $argv 3]
	set IP_TYPE0 [lindex $argv 3]
	set PROJ_NAME [lindex $argv 4]
    }


puts "Board: $BOARD"
puts "Part: $PART"
puts "IP name: $IP_NAME"
puts "IP Type: $IP_TYPE0"
puts "Project name: $PROJ_NAME"

set origin_dir [file dirname [info script]]

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/"]"

# Create project
create_project $PROJ_NAME ./vivado_project -force

puts "project_creation: set project directory"

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

puts "project_creation: set project properties"

# Set project properties
set obj [get_projects $PROJ_NAME]
set_property "board_part" $BOARD $obj
set_property "default_lib" "xil_defaultlib" $obj
set_property "simulator_language" "Mixed" $obj
set_property "target_language" "VHDL" $obj


puts "project_creation: create fileset"

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
  }

  puts "project_creation: set IP repository paths"

  # Set IP repository paths
  set obj [get_filesets sources_1]
  set_property "ip_repo_paths" "[file normalize "$origin_dir/ip_repo"]" $obj

create_peripheral hws.aisec.fraunhofer.de $IP_TYPE0 $IP_NAME 1.0 -dir ./ip_repo
add_peripheral_interface S00_AXI -interface_mode slave -axi_type lite [ipx::find_open_core hws.aisec.fraunhofer.de:$IP_TYPE0:$IP_NAME:1.0]
set_property VALUE 22 [ipx::get_bus_parameters WIZ_NUM_REG -of_objects [ipx::get_bus_interfaces S00_AXI -of_objects [ipx::find_open_core hws.aisec.fraunhofer.de:$IP_TYPE0:$IP_NAME:1.0]]]

generate_peripheral -driver -bfm_example_design -debug_hw_example_design [ipx::find_open_core hws.aisec.fraunhofer.de:$IP_TYPE0:$IP_NAME:1.0]
write_peripheral [ipx::find_open_core hws.aisec.fraunhofer.de:$IP_TYPE0:$IP_NAME:1.0]
set_property  ip_repo_paths  {./ip_repo/$IP_NAME ./ip_repo} [current_project]
update_ip_catalog -rebuild

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
