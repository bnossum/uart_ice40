#
# Makefile for building the project with Clifford Wolf's Yosys ICE40 synthesis
# tools for the Lattice ICE40HX1K-STICK-EVN eval board (aka the "iCEstick")
#

TARGET = uart_ice40
SOURCES = icestick_uart.v uart.v
CONSTRAINTS = top_pcf_sbt.pcf


.PHONY: all prog clean

all: $(TARGET).bin $(TARGET).ex

$(TARGET).txt: $(SOURCES) $(CONSTRAINTS) Makefile
	yosys -q -p "synth_ice40 -abc2 -blif $(TARGET).blif" -p "show -format svg -prefix $(TARGET)"  $(SOURCES)
	arachne-pnr -p $(CONSTRAINTS) $(TARGET).blif -o $(TARGET).txt

$(TARGET).bin: $(TARGET).txt
	icepack $(TARGET).txt $(TARGET).bin

$(TARGET).ex: $(TARGET).txt
	icebox_explain $(TARGET).txt > $(TARGET).ex

prog: $(TARGET).bin
	iceprog $(TARGET).bin

clean:
	rm -f $(TARGET).bin $(TARGET).blif $(TARGET).dot $(TARGET).ex $(TARGET).svg $(TARGET).txt
