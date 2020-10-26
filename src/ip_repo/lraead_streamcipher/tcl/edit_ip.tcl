if { $argc != 2 } {
        puts "The script requires five inputs. BOARD, PART, PROJ_NAME, IPCORE, VIVADO_VER"
	puts "Set to default values for zedboard"
	set PROJ_NAME "sec_boot"
	} else {
	set PROJ_NAME [lindex $argv 0]
	set IP_NAME [lindex $argv 1]
    }

set origin_dir [file dirname [info script]]

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir/"]"
# Open project
open_project  ./vivado_project/$PROJ_NAME.xpr 

ipx::edit_ip_in_project -upgrade true -name lraead_streamcipher_v1_0_project -directory ./vivado_project/sec_boot.tmp/lraead_streamcipher_v1_0_project ./ip_repo/lraead_streamcipher_1.0/component.xml

# add design sources
add_files -norecurse -copy_to ./ip_repo/lraead_streamcipher_1.0/hdl {./src/ip_repo/lraead_streamcipher/hdl/aes_lrpf_streamcipher-ea.vhd ./src/ip_repo/lraead_streamcipher/hdl/aes_icap_data.vhd}
add_files -norecurse -copy_to ./ip_repo/lraead_streamcipher_1.0/hdl {./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/hws_aes-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/keysched_core-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/sboxalg.v ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/column_mult-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/shiftrows-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/addroundkey-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/keysched-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/mixcolumns-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/subbytes-ea.vhd ./src/ip_repo/lr_aes_ofb_gmac_1.0/hdl/global-p.vhd}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

#package IP Core
ipx::merge_project_changes files [ipx::current_core]
ipx::merge_project_changes hdl_parameters [ipx::current_core]
set_property previous_version_for_upgrade hws.aisec.fraunhofer.de:crypto_cores:lraead_streamcipher:1.0 [ipx::current_core]
set_property core_revision 1 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

write_peripheral [ipx::find_open_core hws.aisec.fraunhofer.de:crypto_cores:$IP_NAME:1.0]
update_ip_catalog -rebuild
