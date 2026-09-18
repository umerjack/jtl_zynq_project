# ============================================================
# JLT Zynq Project - Create Project
# Vivado 2019.2
# Part: xc7z010clg400-1
# ============================================================

set project_root [file normalize [file dirname [info script]]]
set project_root [file normalize "$project_root/.."]

set project_name "project_1"
set project_dir  "$project_root/project_build"

set rtl_file "$project_root/src/rtl/jlt_rx_fanout.v"
set bd_script "$project_root/src/bd/design_1.tcl"
set xdc_file "$project_root/constraints/pin_out.xdc"

set part "xc7z010clg400-1"

puts "=========================================="
puts " JLT Zynq - CREATE PROJECT"
puts "=========================================="
puts "Project root : $project_root"
puts "Project dir  : $project_dir"
puts "Part         : $part"
puts "=========================================="

# ------------------------------------------------------------
# Remove previous project
# ------------------------------------------------------------

if {[file exists $project_dir]} {
    puts "Removing previous project..."
    file delete -force $project_dir
}

file mkdir $project_dir

# ------------------------------------------------------------
# Create project from FPGA part
# ------------------------------------------------------------

puts "Creating Vivado project..."

create_project \
    $project_name \
    $project_dir \
    -part $part

# ------------------------------------------------------------
# Add RTL
# ------------------------------------------------------------

puts "Adding RTL..."

add_files \
    -norecurse \
    $rtl_file

# ------------------------------------------------------------
# Add constraints
# ------------------------------------------------------------

puts "Adding constraints..."

add_files \
    -fileset constrs_1 \
    -norecurse \
    $xdc_file

# ------------------------------------------------------------
# Create Block Design
# ------------------------------------------------------------

puts "Creating Block Design..."

source $bd_script

# ------------------------------------------------------------
# Find Block Design
# ------------------------------------------------------------

set bd_file [get_files -quiet */design_1.bd]

if {$bd_file eq ""} {
    error "design_1.bd was not created."
}

puts "Block Design:"
puts "$bd_file"

# ------------------------------------------------------------
# Open and validate Block Design
# ------------------------------------------------------------

open_bd_design $bd_file

puts "Validating Block Design..."

validate_bd_design

# ------------------------------------------------------------
# Generate Block Design
# ------------------------------------------------------------

puts "Generating Block Design..."

generate_target all $bd_file

# ------------------------------------------------------------
# Create HDL wrapper
# ------------------------------------------------------------

puts "Creating HDL wrapper..."

make_wrapper \
    -files $bd_file \
    -top

# Vivado 2019.2 generates the wrapper under project.srcs
set wrapper_file [glob -nocomplain \
    "$project_dir/project_1.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v"]

if {[llength $wrapper_file] == 0} {
    error "design_1_wrapper.v was not generated."
}

puts "Wrapper:"
puts "$wrapper_file"

# ------------------------------------------------------------
# Add wrapper
# ------------------------------------------------------------

add_files \
    -norecurse \
    $wrapper_file

# ------------------------------------------------------------
# Set Block Design wrapper as TOP
# ------------------------------------------------------------

update_compile_order -fileset sources_1

set_property top design_1_wrapper [current_fileset]

puts "Top module: design_1_wrapper"

# ------------------------------------------------------------
# Finalize project
# ------------------------------------------------------------

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "=========================================="
puts " PROJECT CREATION COMPLETE"
puts "=========================================="
puts "Project:"
puts "$project_dir/$project_name.xpr"
puts ""
puts "Top:"
puts "design_1_wrapper"
puts "=========================================="

close_project
exit
