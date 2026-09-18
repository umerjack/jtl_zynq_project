# ============================================================
# JLT Zynq Project - Build
# Vivado 2019.2
#
# Performs:
#   Synthesis
#   Implementation
#   Bitstream generation
#   XSA export
# ============================================================

set project_root [file normalize [file dirname [info script]]]
set project_root [file normalize "$project_root/.."]

set project_dir  "$project_root/project_build"
set project_file "$project_dir/project_1.xpr"

set bit_file "$project_dir/project_1.bit"
set xsa_file "$project_dir/project_1.xsa"

puts "=========================================="
puts " JLT Zynq - BUILD"
puts "=========================================="

# ------------------------------------------------------------
# Check project
# ------------------------------------------------------------

if {![file exists $project_file]} {
    error "Vivado project does not exist: $project_file\nRun 'make project' first."
}

# ------------------------------------------------------------
# Open project
# ------------------------------------------------------------

puts "Opening project..."

open_project $project_file

# ------------------------------------------------------------
# Check top module
# ------------------------------------------------------------

set top_module [get_property top [current_fileset]]

puts "Top module: $top_module"

if {$top_module ne "design_1_wrapper"} {
    error "Wrong top module: $top_module\nExpected: design_1_wrapper"
}

# ------------------------------------------------------------
# Synthesis
# ------------------------------------------------------------

puts "=========================================="
puts " Starting Synthesis"
puts "=========================================="

reset_run synth_1

launch_runs synth_1 -jobs 4

wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]

puts "Synthesis status: $synth_status"

if {![string match "*Complete*" $synth_status]} {
    error "Synthesis failed."
}

# ------------------------------------------------------------
# Implementation + Bitstream
# ------------------------------------------------------------

puts "=========================================="
puts " Starting Implementation"
puts "=========================================="

reset_run impl_1

launch_runs impl_1 \
    -to_step write_bitstream \
    -jobs 4

wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]

puts "Implementation status: $impl_status"

if {![string match "*Complete*" $impl_status]} {
    error "Implementation failed."
}

# ------------------------------------------------------------
# Locate generated bitstream
# ------------------------------------------------------------

set generated_bit \
    "$project_dir/project_1.runs/impl_1/design_1_wrapper.bit"

if {![file exists $generated_bit]} {
    error "Bitstream was not generated: $generated_bit"
}

# ------------------------------------------------------------
# Copy bitstream
# ------------------------------------------------------------

file copy -force \
    $generated_bit \
    $bit_file

puts "Bitstream:"
puts "$bit_file"

# ------------------------------------------------------------
# Export XSA
# ------------------------------------------------------------

puts "=========================================="
puts " Exporting Hardware"
puts "=========================================="

write_hw_platform \
    -fixed \
    -include_bit \
    -force \
    -file $xsa_file

puts "XSA:"
puts "$xsa_file"

# ------------------------------------------------------------
# Build complete
# ------------------------------------------------------------

puts "=========================================="
puts " BUILD COMPLETE"
puts "=========================================="
puts ""
puts "BIT : $bit_file"
puts "XSA : $xsa_file"
puts "=========================================="

close_project
exit
