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
# Keep heirarchy for LR-AES
# ----------------------------------------------------------------------------
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/ghash_0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/mixcolumns0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/subbytes0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/shiftrows0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/keysched0]]
set_property DONT_TOUCH true [get_cells [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/addroundkey0]]
# ----------------------------------------------------------------------------
# Constrain AES-GMAC within the pblock
# ----------------------------------------------------------------------------
create_pblock aes_gmac
add_cells_to_pblock [get_pblocks aes_gmac] [get_cells -quiet [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int]]
resize_pblock [get_pblocks aes_gmac] -add {SLICE_X80Y100:SLICE_X113Y149}
resize_pblock [get_pblocks aes_gmac] -add {DSP48_X3Y40:DSP48_X4Y59}
resize_pblock [get_pblocks aes_gmac] -add {RAMB18_X4Y40:RAMB18_X5Y59}
resize_pblock [get_pblocks aes_gmac] -add {RAMB36_X4Y20:RAMB36_X5Y29}
set_property CONTAIN_ROUTING 1 [get_pblocks aes_gmac]

# ----------------------------------------------------------------------------
# Constrain AES within the pblock
# ----------------------------------------------------------------------------
create_pblock pblock_hws_aes
add_cells_to_pblock [get_pblocks pblock_hws_aes] [get_cells -quiet [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0]]
resize_pblock [get_pblocks pblock_hws_aes] -add {SLICE_X80Y100:SLICE_X113Y127}
set_property CONTAIN_ROUTING 1 [get_pblocks pblock_hws_aes]

# ----------------------------------------------------------------------------
# Constrain GHASH within the pblock
# ----------------------------------------------------------------------------
create_pblock pblock_ghash
add_cells_to_pblock [get_pblocks pblock_ghash] [get_cells -quiet [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/ghash_0]]
resize_pblock [get_pblocks pblock_ghash] -add {SLICE_X94Y129:SLICE_X113Y149}
set_property CONTAIN_ROUTING 1 [get_pblocks pblock_ghash]

# ----------------------------------------------------------------------------
# Constrain subbytes, mixcolumns and shiftrows within the pblock
# ----------------------------------------------------------------------------
create_pblock pblock_subbytes_mixcolumns_shiftrows
add_cells_to_pblock [get_pblocks pblock_subbytes_mixcolumns_shiftrows] [get_cells -quiet [list zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/mixcolumns0 zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/shiftrows0 zynq_design_i/lr_aes_ofb_gmac_0/U0/lr_aes_ofb_gmac_v1_0_S00_AXI_inst/aes_ui_lrprf_ofb_gmac_int/hws_aes_0/subbytes0]]
resize_pblock [get_pblocks pblock_subbytes_mixcolumns_shiftrows] -add {SLICE_X90Y102:SLICE_X105Y126}
set_property CONTAIN_ROUTING 1 [get_pblocks pblock_subbytes_mixcolumns_shiftrows]
