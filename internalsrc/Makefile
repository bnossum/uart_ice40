#
# Project :
# Author  : Baard Nossum
#
# Depenencies:
#   make     obviously
#   lualatex for documentation
#   latexmk  for documentation
#   noweb    for documentation
#############################################################################

PN=uartICE40
PN_DOC_WRAP=uartICE40docwrap
DOCDIR=../doc
OBJDIR=../obj
CODEDIR=../src
SIMLIBDIR = ../../../../PROJ/iCE_simlib/
DIR_GUARD=@mkdir -p $(@D)

all: doc code sim

THEDOC=$(DOCDIR)/$(PN).pdf
THECODE=$(CODEDIR)/uartICE40hl.v $(CODEDIR)/uartICE40.v $(CODEDIR)/tbuartICE40.v \
	$(CODEDIR)/icestickuart.v
THESIM=$(OBJDIR)/tst00.lxt $(OBJDIR)/tst01.lxt $(OBJDIR)/tst10.lxt $(OBJDIR)/tst11.lxt \
	$(OBJDIR)/ltst00.lxt $(OBJDIR)/ltst01.lxt $(OBJDIR)/ltst10.lxt $(OBJDIR)/ltst11.lxt 
doc:$(THEDOC)
code:$(THECODE)
sim:$(THESIM)

# Documentation
$(DOCDIR)/$(PN).pdf:$(OBJDIR)/$(PN_DOC_WRAP).tex $(OBJDIR)/e$(PN).tex
	$(DIR_GUARD)
	latexmk -pdf -pdflatex="lualatex" -use-make $<
	mv $(PN_DOC_WRAP).pdf $@

# To get code in the .v file, but avoid documentation, I use tags <<notindoc:blah blah>>
# The chunk itself is removed with the elide filter during noweave, while references
# to the chunk is removed by a reverse grep
$(OBJDIR)/e$(PN).tex:$(OBJDIR)/$(PN).tex
	$(DIR_GUARD)
	grep -v "notindoc" $< > $@

$(OBJDIR)/$(PN).tex:$(PN).nw $(OBJDIR)/$(PN_DOC_WRAP).tex
	$(DIR_GUARD)
	noweave -filter "elide showlistfile*" -filter "elide notindoc:*" -n -index -latex $< > $@

$(OBJDIR)/$(PN_DOC_WRAP).tex:$(PN).nw 
	$(DIR_GUARD)
	notangle -R$(*F) $< > $@

# Code
$(CODEDIR)/uartICE40hl.v:$(PN).nw 
	$(DIR_GUARD)
	notangle -R$@ $< > $@
	emacs --batch  $@  -f verilog-batch-auto
	emacs --batch  $@  -f verilog-batch-auto

$(CODEDIR)/uartICE40.v:$(PN).nw 
	$(DIR_GUARD)
	notangle -R$@ $< > $@
	emacs --batch  $@  -f verilog-batch-auto
	emacs --batch  $@  -f verilog-batch-auto

$(CODEDIR)/tbuartICE40.v:$(PN).nw 
	$(DIR_GUARD)
	notangle -R$@ $< > $@
	emacs --batch  $@  -f verilog-batch-auto
	emacs --batch  $@  -f verilog-batch-auto

$(CODEDIR)/icestickuart.v:$(PN).nw 
	$(DIR_GUARD)
	notangle -R$@ $< > $@
	emacs --batch  $@  -f verilog-batch-auto
	emacs --batch  $@  -f verilog-batch-auto


# Clumsy here. Want to simulate all combinations of
# SUBDIV16   = 0 // 8 times oversampling of rx
#            = 1 // 16 times oversampling of rx
# BITCELAX   = 0 // Continuous bitxce pulses. This corresponds to highest acheivable bitrate
#            = 1 // We let there be 8 cycles between each bitxce pulse
# All these 4 combinations for both the high-level, and the low-level implementation, for
# a total of 8 simulations.
#
$(OBJDIR)/tst00.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40hl.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=0 -DBITLAX=0 -DTSTFILE=\"../obj/tst00.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt

$(OBJDIR)/tst01.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40hl.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=0 -DBITLAX=1 -DTSTFILE=\"../obj/tst01.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt

$(OBJDIR)/tst10.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40hl.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=1 -DBITLAX=0 -DTSTFILE=\"../obj/tst10.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt

$(OBJDIR)/tst11.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40hl.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=1 -DBITLAX=1 -DTSTFILE=\"../obj/tst11.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt


$(OBJDIR)/ltst00.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=0 -DBITLAX=0 -DTSTFILE=\"../obj/ltst00.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt

$(OBJDIR)/ltst01.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=0 -DBITLAX=1 -DTSTFILE=\"../obj/ltst01.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt

$(OBJDIR)/ltst10.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=1 -DBITLAX=0 -DTSTFILE=\"../obj/ltst10.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt

$(OBJDIR)/ltst11.lxt:$(CODEDIR)/tbuartICE40.v $(CODEDIR)/uartICE40.v
	$(DIR_GUARD)
	iverilog -o $(OBJDIR)/w1 -DSIMULATION -DSUBDIV16=1 -DBITLAX=1 -DTSTFILE=\"../obj/ltst11.lxt\" \
	$^  $(SIMLIBDIR)/iCE_simlib.v 
	vvp $(OBJDIR)/w1 -lxt


clean:
	rm -f $(PN_DOC_WRAP).* $(THEDOC) $(THECODE) $(THESIM)
	rm -f $(OBJDIR)/$(PN_DOC_WRAP).tex $(OBJDIR)/e$(PN).tex $(OBJDIR)/$(PN).tex $(OBJDIR)/w1 
