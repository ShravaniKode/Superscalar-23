GHDL=ghdl 

all:
	@$(GHDL) -a decode_stage_final.vhdl testbench.vhdl
	@$(GHDL) -e testbench_tb
	@$(GHDL) -r testbench_tb --wave=wave.ghw --stop-time=50ns
	@gtkwave wave.ghw signals.gtkw

