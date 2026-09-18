VIVADO := /tools/Xilinx/Vivado/2019.2/bin/vivado
VITIS_SETTINGS := /tools/Xilinx/Vitis/2019.2/settings64.sh
XSCT := xsct

VIVADO_DIR := vivado
VITIS_DIR := vitis

VIVADO_PROJECT_SCRIPT := $(VIVADO_DIR)/scripts/create_project.tcl
VIVADO_BUILD_SCRIPT := $(VIVADO_DIR)/scripts/build_project.tcl
VITIS_SCRIPT := $(VITIS_DIR)/scripts/create_vitis_project.tcl

VIVADO_PROJECT_DIR := $(VIVADO_DIR)/project_build
VIVADO_XPR := $(VIVADO_PROJECT_DIR)/project_1.xpr
XSA := $(VIVADO_PROJECT_DIR)/project_1.xsa
VITIS_WS := $(VITIS_DIR)/workspace

.PHONY: all generate build vitis rebuild clean clean-vivado clean-vitis

all: build vitis

generate: $(VIVADO_XPR)

$(VIVADO_XPR):
	$(VIVADO) -mode batch -source $(VIVADO_PROJECT_SCRIPT)

build: $(XSA)

$(XSA): $(VIVADO_XPR)
	$(VIVADO) -mode batch -source $(VIVADO_BUILD_SCRIPT)

vitis: $(XSA)
	bash -c "source $(VITIS_SETTINGS) && $(XSCT) $(VITIS_SCRIPT)"

clean-vivado:
	@echo "Cleaning Vivado..."
	rm -rf $(VIVADO_PROJECT_DIR)
	rm -f $(VIVADO_DIR)/vivado*.log
	rm -f $(VIVADO_DIR)/vivado*.jou
	rm -f $(VIVADO_DIR)/vivado*.str
	rm -f vivado*.log
	rm -f vivado*.jou
	rm -f vivado*.str
	@echo "Vivado clean complete."

clean-vitis:
	@echo "Cleaning Vitis..."
	rm -rf $(VITIS_WS)
	@echo "Vitis clean complete."

clean: clean-vivado clean-vitis
	@echo "Complete clean finished."

rebuild: clean all
