#
# Vivado (TM) v2017.2 (64-bit)
#

if { $argc != 7 } {
        puts "The script requires five inputs. BOARD, PART, PROJ_NAME, IPCORE, VIVADO_VER"
	puts "Set to default values for zedboard"
	set BOARD "em.avnet.com:zed:part0:1.3"
	set PART "xc7z020clg484-1"
	set PROJ_NAME "project_1"
	set VIVADO_VER "2017.2"
	set ZYNQ_CONFIG "DEFAULT"
	set BLOCK_LENGTH 128
	set IPCORE "AES"
	} else {
		set BOARD [lindex $argv 0]
	set PART [lindex $argv 1]
	set PROJ_NAME [lindex $argv 2]
	set VIVADO_VER [lindex $argv 3]
	set ZYNQ_CONFIG [lindex $argv 4]
	set BLOCK_LENGTH [lindex $argv 5]
	set IP_CORE [lindex $argv 6]
    }


puts "Board: $BOARD"
puts "Part: $PART"
puts "Project: $PROJ_NAME"
puts "Vivado version: $VIVADO_VER"
puts "Zynq Config: $ZYNQ_CONFIG"
puts "Block length: $BLOCK_LENGTH"
puts "IP CORE for Decryption: $IP_CORE"


# Set the reference directory for source file relative paths (by default the value is script directory path)
#set origin_dir "."
set origin_dir [file dirname [info script]]

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/"]"

puts "project_creation: create project $PROJ_NAME"

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

puts "project_creation: update IP catalog"

# Rebuild user ip_repo's index before adding any source files
update_ip_catalog -rebuild

# add puf to ip library
set_property ip_repo_paths $origin_dir/ip_repo [current_project]
update_ip_catalog
#
puts "project_creation: source sript \"zynq_design.tcl\""

# Create block design
source $origin_dir/src/bd/zynq_design.tcl

#report_ip_status

# Generate the wrapper
set design_name [get_bd_designs]
make_wrapper -files [get_files $design_name.bd] -top -import

# Set 'sources_1' fileset file properties for remote files
# None

# Set 'sources_1' fileset file properties for local files
set file "zynq_design.bd"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
if { ![get_property "is_locked" $file_obj] } {
  set_property "generate_synth_checkpoint" "0" $file_obj
}

#set file "hdl/zynq_design_wrapper.vhd"
set file "zynq_design_wrapper.vhd"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property "file_type" "VHDL" $file_obj


# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property "top" "zynq_design_wrapper" $obj

if {$IP_CORE=="LRAES_OFB_GMAC"} {
	puts "Contraints.xdc"
	add_files -fileset constrs_1 -norecurse src/constraints.xdc
} elseif {$IP_CORE == "LRAEAD_STREAMCIPHER"} {
	puts "Contraints_lraead.xdc"
	add_files -fileset constrs_1 -norecurse src/constraints_lraead.xdc
} else {
	puts "Invalid IP Core: $IP_CORE"
	exit 1
}
# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Empty (no sources present)

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property "top" "zynq_design_wrapper" $obj
set_property "xsim.compile.xvhdl.nosort" "1" $obj
set_property "xelab.unifast" "" $obj

puts "INFO: Project created:$PROJ_NAME"
