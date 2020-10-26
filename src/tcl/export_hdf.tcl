if { $argc != 1 } {
	    puts "The script requires one input. PROJ_NAME"
	puts "Set to default values for zedboard"
	set PROJ_NAME "project_1"
	} else {
		set PROJ_NAME [lindex $argv 0]
	}
puts  "export sdk-Project name: $PROJ_NAME"
open_project vivado_project/$PROJ_NAME.xpr
file mkdir vivado_project/$PROJ_NAME.sdk
write_hwdef -force  -file ./vivado_project/$PROJ_NAME.sdk/zynq_design_wrapper.hdf
exit
