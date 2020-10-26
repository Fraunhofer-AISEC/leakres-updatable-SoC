if { $argc != 3 } {
    puts "The script requires five inputs. BOARD, PART, PROJ_NAME, IPCORE, VIVADO_VER"
	puts "Set to default values for zedboard"
	set PROJ_NAME "zedboardRevD_SEC_UP_DEMO"
	set IP_NAME "pr_ctrl_axi"
	set COMPANY_NAME "misc"
	} else {
	set PROJ_NAME [lindex $argv 0]
	set IP_NAME [lindex $argv 1]
	set COMPANY_NAME [lindex $argv 2]
    }

set origin_dir [file dirname [info script]]
puts "IP NAME: $IP_NAME" 

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/"]"
# Open project
open_project  ./vivado_project/$PROJ_NAME.xpr 
ipx::edit_ip_in_project -upgrade true -name pr_controller_v1_0_project -directory ./vivado_project/zedboardRevD_SEC_UP_DEMO.tmp/pr_controller_v1_0_project ./ip_repo/pr_controller_1.0/component.xml

add_files -norecurse -copy_to ./ip_repo/pr_controller_1.0/hdl {./src/ip_repo/pr_controller/pr_controller.vhd}
update_compile_order -fileset sources_1
#package IP Core
ipx::merge_project_changes files [ipx::current_core]
ipx::merge_project_changes hdl_parameters [ipx::current_core]
set_property previous_version_for_upgrade hws.aisec.fraunhofer.de:$COMPANY_NAME:$IP_NAME:1.0 [ipx::current_core]
set_property core_revision 2 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

write_peripheral [ipx::find_open_core hws.aisec.fraunhofer.de:$COMPANY_NAME:$IP_NAME:1.0]
update_ip_catalog -rebuild
