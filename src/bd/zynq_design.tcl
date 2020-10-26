################################################################
# Check if script is running in correct Vivado version.
################################################################

puts "IP_CORE: $IP_CORE"
set scripts_vivado_version $VIVADO_VER 
set current_vivado_version [version -short]
puts " scripts vivado ver: $scripts_vivado_version"

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   puts "ERROR: This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."

   return 1
}



################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source zynq_design_script.tcl

# If you do not already have a project created,
# you can create a project using the following command:
#    create_project project_1 myproj -part xc7z020clg484-1
#    set_property BOARD_PART em.avnet.com:zed:part0:1.3 [current_project]

# CHECKING IF PROJECT EXISTS
if { [get_projects -quiet] eq "" } {
   puts "ERROR: Please open or create a project!"
   return 1
}



# CHANGE DESIGN NAME HERE
set design_name zynq_design

# This script was generated for a remote BD.
set str_bd_folder src/bd
set str_bd_filepath ${str_bd_folder}/${design_name}/${design_name}.bd

# Check if remote design exists on disk
if { [file exists $str_bd_filepath ] == 1 } {
   puts "ERROR: The remote BD file path <$str_bd_filepath> already exists!"
   return 1
}

# Check if design exists in memory
set list_existing_designs [get_bd_designs -quiet $design_name]
if { $list_existing_designs ne "" } {
   puts "ERROR: The design <$design_name> already exists in this project!"
   puts "ERROR: Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."

   return 1
}

# Check if design exists on disk within project
set list_existing_designs [get_files */${design_name}.bd]
if { $list_existing_designs ne "" } {
   puts "ERROR: The design <$design_name> already exists in this project at location:"
   puts "   $list_existing_designs"
   puts "ERROR: Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."

   return 1
}

puts "zynq_design: create a new design"

# Now can create the remote BD
create_bd_design -dir $str_bd_folder $design_name
puts "zynq_design: set \"$design_name\" to current design"
current_bd_design $design_name

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell IP_CORE } {

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }
  puts "IP_CORE: $IP_CORE"

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     puts "ERROR: Unable to find parent cell <$parentCell>!"
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create instance: processing_system7_0, and set properties
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]

  set_property -dict [ list CONFIG.preset $::ZYNQ_CONFIG  ] $processing_system7_0

  set DDR [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR ]
  set FIXED_IO [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO ]

  connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins processing_system7_0/DDR]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]


  # Create instance: rst_processing_system7_0_102M
  set rst_processing_system7_0_102M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_processing_system7_0_102M ]

  connect_bd_net -net processing_system7_0_FCLK_RESET0_N [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_processing_system7_0_102M/ext_reset_in]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins rst_processing_system7_0_102M/slowest_sync_clk]


  # Create instance: processing_system7_0_axi_periph
  set processing_system7_0_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 processing_system7_0_axi_periph ]

  set_property -dict [ list CONFIG.NUM_MI {5}  ] $processing_system7_0_axi_periph

  connect_bd_intf_net -intf_net processing_system7_0_M_AXI_GP0 [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins processing_system7_0_axi_periph/S00_AXI]
  connect_bd_net -net rst_processing_system7_0_102M_interconnect_aresetn [get_bd_pins processing_system7_0_axi_periph/ARESETN] [get_bd_pins rst_processing_system7_0_102M/interconnect_aresetn]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins processing_system7_0_axi_periph/M00_ARESETN] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins processing_system7_0_axi_periph/M01_ARESETN] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins processing_system7_0_axi_periph/M02_ARESETN] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins processing_system7_0_axi_periph/M03_ARESETN] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins processing_system7_0_axi_periph/M04_ARESETN] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins processing_system7_0_axi_periph/S00_ARESETN] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]

  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0_axi_periph/ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0_axi_periph/M00_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0_axi_periph/M01_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0_axi_periph/M02_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0_axi_periph/M03_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0_axi_periph/M04_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins processing_system7_0_axi_periph/S00_ACLK] [get_bd_pins processing_system7_0/FCLK_CLK0]

 # # Create instance: fuzzy_commitment_puf_axi_0
  set fuzzy_key_commitment_0 [ create_bd_cell -type ip -vlnv qub.ac.uk:csit:fuzzy_key_commitment:1.0 fuzzy_key_commitment_0]
  # connect AXI
  connect_bd_intf_net -intf_net processing_system7_0_axi_periph_M03_AXI [get_bd_intf_pins fuzzy_key_commitment_0/S00_AXI] [get_bd_intf_pins processing_system7_0_axi_periph/M03_AXI]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins fuzzy_key_commitment_0/s00_axi_aclk] [get_bd_pins processing_system7_0_axi_periph/ACLK]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins fuzzy_key_commitment_0/s00_axi_aresetn] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]


  # Create instance: pr_controller_0
  set pr_controller_0 [ create_bd_cell -type ip -vlnv hws.aisec.fraunhofer.de:configuration:pr_controller:1.0 pr_controller_0 ]
  # connect AXI
  connect_bd_intf_net -intf_net processing_system7_0_axi_periph_M01_AXI [get_bd_intf_pins pr_controller_0/S00_AXI] [get_bd_intf_pins processing_system7_0_axi_periph/M01_AXI]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins pr_controller_0/s00_axi_aclk] [get_bd_pins processing_system7_0_axi_periph/ACLK]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins pr_controller_0/s00_axi_aresetn] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]

  # Create AES core instance based on the IP_CORE to be instantiated
  # "LRAES_OFB_GMAC"
  if {$IP_CORE=="LRAES_OFB_GMAC"} { 
	  puts "LR_AES_OFB_GMAC"
	  # Create instance: lr_aes_ofb_gmac_0
	  set lr_aes_ofb_gmac_0 [ create_bd_cell -type ip -vlnv hws.aisec.fraunhofer.de:crypto_cores:lr_aes_ofb_gmac:1.0 lr_aes_ofb_gmac_0 ]


	  set_property -dict [list CONFIG.BLOCK_LENGTH_G $::BLOCK_LENGTH] $lr_aes_ofb_gmac_0

	  connect_bd_intf_net -intf_net processing_system7_0_axi_periph_M00_AXI [get_bd_intf_pins lr_aes_ofb_gmac_0/S00_AXI] [get_bd_intf_pins processing_system7_0_axi_periph/M00_AXI]
	  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins lr_aes_ofb_gmac_0/s00_axi_aclk] [get_bd_pins processing_system7_0_axi_periph/ACLK]
	  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins lr_aes_ofb_gmac_0/s00_axi_aresetn] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]

	  #Connect to PUF
	  connect_bd_net [get_bd_pins lr_aes_ofb_gmac_0/fe_key] [get_bd_pins fuzzy_key_commitment_0/key_o]
	  # connect lr_aes_ofb_gmac_0
	  connect_bd_net -net icap_controller_ctw [get_bd_pins pr_controller_0/tready] [get_bd_pins lr_aes_ofb_gmac_0/icap_tready]
	  connect_bd_net -net icap_controller_abort [get_bd_pins pr_controller_0/abort] [get_bd_pins lr_aes_ofb_gmac_0/icap_abort]
	  connect_bd_net -net icap_controller_dv [get_bd_pins pr_controller_0/tvalid] [get_bd_pins lr_aes_ofb_gmac_0/icap_tvalid]
	  connect_bd_net -net icap_controller_data [get_bd_pins pr_controller_0/tdata] [get_bd_pins lr_aes_ofb_gmac_0/icap_tdata] 
	  # AXI address space
	  create_bd_addr_seg -range 0x10000 -offset 0x6B040000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs lr_aes_ofb_gmac_0/S00_AXI/S00_AXI_reg] SEG_lr_aes_ofb_gmac_0_reg

} elseif {$IP_CORE == "LRAEAD_STREAMCIPHER"} {
	# Create instance: lraead_streamcipher_0
	puts "LRAEAD_STREAMCIPHER"
	set lraead_streamcipher_0 [ create_bd_cell -type ip -vlnv hws.aisec.fraunhofer.de:crypto_cores:lraead_streamcipher:1.0 lraead_streamcipher_0]

	connect_bd_intf_net -intf_net processing_system7_0_axi_periph_M00_AXI [get_bd_intf_pins lraead_streamcipher_0/S00_AXI] [get_bd_intf_pins processing_system7_0_axi_periph/M00_AXI]
	connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins lraead_streamcipher_0/s00_axi_aclk] [get_bd_pins processing_system7_0_axi_periph/ACLK]
	connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins lraead_streamcipher_0/s00_axi_aresetn] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]

	#Connect to PUF
	connect_bd_net [get_bd_pins lraead_streamcipher_0/fe_key] [get_bd_pins fuzzy_key_commitment_0/key_o]
	# connect lraeas_streamcipher
	connect_bd_net -net icap_controller_ctw [get_bd_pins pr_controller_0/tready] [get_bd_pins lraead_streamcipher_0/icap_tready]
	connect_bd_net -net icap_controller_abort [get_bd_pins pr_controller_0/abort] [get_bd_pins lraead_streamcipher_0/icap_abort]
	connect_bd_net -net icap_controller_dv [get_bd_pins pr_controller_0/tvalid] [get_bd_pins lraead_streamcipher_0/icap_tvalid]
	connect_bd_net -net icap_controller_data [get_bd_pins pr_controller_0/tdata] [get_bd_pins lraead_streamcipher_0/icap_tdata] 
	# AXI address space
	create_bd_addr_seg -range 0x10000 -offset 0x6B040000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs lraead_streamcipher_0/S00_AXI/S00_AXI_reg] SEG_lraead_streamcipher_reg
} else {
	#ERROR due to invalid IP_CORE
		puts "Invalid IP core: $IP_CORE"
		exit 1
	}

  # Create instance: pr_decoupler
  set pr_decoupler_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:pr_decoupler:1.0 pr_decoupler_0]

  # IMPORTANT:
  # Using Xilinx's definition for AXI4Lite doesn't work here: WSTRB has too less bits (4 needed). Also some other signals are missing.
  # In the folloing the properties of these signals are set manually to their correct values.
  set_property -dict [list CONFIG.ALL_PARAMS {HAS_SIGNAL_CONTROL 0 HAS_SIGNAL_STATUS 0 HAS_AXI_LITE 1 INTF {S00_AXI_led_driver {ID 0 VLNV xilinx.com:interface:aximm_rtl:1.0 MODE slave PROTOCOL axi4lite SIGNALS {WSTRB {MANAGEMENT manual DIRECTION in WIDTH 4} AWPROT {MANAGEMENT manual PRESENT 1 DIRECTION in} BRESP {MANAGEMENT manual DIRECTION out} ARPROT {MANAGEMENT manual PRESENT 1 DIRECTION in} RRESP {MANAGEMENT manual DIRECTION out}}} led_led_driver {ID 1 VLNV xilinx.com:signal:data_rtl:1.0 SIGNALS {DATA {MANAGEMENT manual WIDTH 8}}}}}] [get_bd_cells pr_decoupler_0]

  # connect AXI
  connect_bd_intf_net -intf_net processing_system7_0_axi_periph_M04_AXI [get_bd_intf_pins pr_decoupler_0/s_axi_reg] [get_bd_intf_pins processing_system7_0_axi_periph/M04_AXI]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins pr_decoupler_0/aclk] [get_bd_pins processing_system7_0_axi_periph/ACLK]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins pr_decoupler_0/s_axi_reg_aresetn] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]


  create_bd_port -dir O -from 7 -to 0 LD

  # connect AXI (led_driver_axi_0)
  connect_bd_intf_net -intf_net processing_system7_0_axi_periph_M02_AXI [get_bd_intf_pins pr_decoupler_0/s_S00_AXI_led_driver] [get_bd_intf_pins processing_system7_0_axi_periph/M02_AXI]
  # connect port (led_driver_axi_0)
  connect_bd_net -net pr_decoupler_0_ld [get_bd_ports LD] [get_bd_pins pr_decoupler_0/s_led_led_driver_DATA]

  # Create instance: led_driver_axi
  set led_driver_axi_0 [ create_bd_cell -type ip -vlnv hws.aisec.fraunhofer.de:misc:led_driver_axi:1.0 led_driver_axi_0 ]

  # connect AXI
  connect_bd_intf_net -intf_net pr_decoupler_0_rp_S00_AXI_led_driver [get_bd_intf_pins pr_decoupler_0/rp_S00_AXI_led_driver] [get_bd_intf_pins led_driver_axi_0/s00_axi]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins led_driver_axi_0/s00_axi_aclk] [get_bd_pins processing_system7_0_axi_periph/ACLK]
  connect_bd_net -net rst_processing_system7_0_102M_peripheral_aresetn [get_bd_pins led_driver_axi_0/s00_axi_aresetn] [get_bd_pins rst_processing_system7_0_102M/peripheral_aresetn]

  # connect led port
  connect_bd_net -net led_driver_axi_0_ld [get_bd_pins led_driver_axi_0/led] [get_bd_pins pr_decoupler_0/rp_led_led_driver_DATA]

  # Create address segments
  create_bd_addr_seg -range 0x10000 -offset 0x43C00000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs fuzzy_key_commitment_0/S00_AXI/S00_AXI_reg] SEG_fuzzy_key_commitment_0_S00_AXI_reg
  create_bd_addr_seg -range 0x10000 -offset 0x6B050000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs led_driver_axi_0/S00_AXI/S00_AXI_reg] SEG_led_driver_axi_0_reg 
  create_bd_addr_seg -range 0x10000 -offset 0x6B060000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs pr_controller_0/S00_AXI/S00_AXI_reg] SEG_pr_controller_axi_0_reg
  create_bd_addr_seg -range 0x10000 -offset 0x6B070000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs pr_decoupler_0/s_axi_reg/Reg] SEG_pr_decoupler_0_reg


  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
}
# End of create_root_design()


create_root_design "" $IP_CORE
