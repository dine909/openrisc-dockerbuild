# Main system clock (50 Mhz)
create_clock -name "sys_clk_pad_i" -period 20.000ns [get_ports {sys_clk_pad_i}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# Ignore timing on the reset input
# set_false_path -through [get_nets {rst_n_pad_i}]

create_clock -name "eth0_tx_clk_pad_i"  -period 40.000ns  [get_ports {eth0_tx_clk_pad_i}] 
create_clock -name "eth0_rx_clk_pad_i"  -period 40.000ns  [get_ports {eth0_rx_clk_pad_i}]
set_false_path -from [get_clocks {clkgen0|pll0|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {eth0_tx_clk_pad_i}]
set_false_path -from [get_clocks {clkgen0|pll0|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {eth0_rx_clk_pad_i}]

