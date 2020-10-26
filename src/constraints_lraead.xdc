###############################################################################
# Copyright © [2020] Gesellschaft zur Foerderung der angewandten Forschung e.V.
# acting on behalf of its Fraunhofer Institute AISEC.
# All rights reserved.
###############################################################################

# ----------------------------------------------------------------------------
# User LEDs - Bank 33
# ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN T22 IOSTANDARD LVCMOS33} [get_ports {LD[0]}]
set_property -dict {PACKAGE_PIN T21 IOSTANDARD LVCMOS33} [get_ports {LD[1]}]
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVCMOS33} [get_ports {LD[2]}]
set_property -dict {PACKAGE_PIN U21 IOSTANDARD LVCMOS33} [get_ports {LD[3]}]
set_property -dict {PACKAGE_PIN V22 IOSTANDARD LVCMOS33} [get_ports {LD[4]}]
set_property -dict {PACKAGE_PIN W22 IOSTANDARD LVCMOS33} [get_ports {LD[5]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {LD[6]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {LD[7]}]

# ----------------------------------------------------------------------------
# Keep heirarchy for LRPRF Streamcipher
# ----------------------------------------------------------------------------
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/mixcolumns0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/subbytes0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/shiftrows0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/keysched0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/addroundkey0]]
# ----------------------------------------------------------------------------
# Constrain AES-GMAC within the pblock
# ----------------------------------------------------------------------------
create_pblock aes_lrprf
add_cells_to_pblock [get_pblocks aes_lrprf] [get_cells -quiet [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int]]
resize_pblock [get_pblocks aes_lrprf] -add {SLICE_X80Y90:SLICE_X113Y135}
resize_pblock [get_pblocks aes_lrprf] -add {DSP48_X3Y36:DSP48_X4Y53}
resize_pblock [get_pblocks aes_lrprf] -add {RAMB18_X4Y36:RAMB18_X5Y53}
resize_pblock [get_pblocks aes_lrprf] -add {RAMB36_X4Y18:RAMB36_X5Y26}
set_property CONTAIN_ROUTING 1 [get_pblocks aes_lrprf]

# ----------------------------------------------------------------------------
# Constrain AES within the pblock
# ----------------------------------------------------------------------------
create_pblock pblock_hws_aes
add_cells_to_pblock [get_pblocks pblock_hws_aes] [get_cells -quiet [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0]]
resize_pblock [get_pblocks pblock_hws_aes] -add {SLICE_X84Y119:SLICE_X113Y135}
set_property CONTAIN_ROUTING 1 [get_pblocks pblock_hws_aes]


# ----------------------------------------------------------------------------
# Constrain subbytes, mixcolumns and shiftrows within the pblock
# ----------------------------------------------------------------------------
create_pblock pblock_subbytes_mixcolumns_shiftrows
add_cells_to_pblock [get_pblocks pblock_subbytes_mixcolumns_shiftrows] [get_cells -quiet [list zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/mixcolumns0 zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/shiftrows0 zynq_design_i/lraead_streamcipher_0/U0/lraead_streamcipher_v1_0_S00_AXI_inst/aes_lrprf_streamcipher_int/hws_aes_0/subbytes0]]
resize_pblock [get_pblocks pblock_subbytes_mixcolumns_shiftrows] -add {SLICE_X80Y92:SLICE_X95Y116}
set_property CONTAIN_ROUTING 1 [get_pblocks pblock_subbytes_mixcolumns_shiftrows]
