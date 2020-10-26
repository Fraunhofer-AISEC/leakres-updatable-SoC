#!/usr/bin/tclsh
if { $argc != 1 } {
	    puts "The script requires one input. PROJ_NAME"
        puts "Set to default values for zedboard"
        set PROJ_NAME "zedboardRevD_PR_dummyAES"
        } else {
	        set PROJ_NAME [lindex $argv 0]
        }
puts  "make firmware-Project name: $PROJ_NAME"
#set workspace
sdk setws vivado_project/$PROJ_NAME.sdk
# build project
sdk projects -build -type bsp -name fsbl_bsp
sdk projects -build -type all

puts "finished build"
exit
