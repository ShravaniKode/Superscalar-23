# RISC based Superscalar Processor

## Course Project - EE 739 - Processor Design

## *Course Instructor - Prof. Virendra Singh*

### This repository contains our design of a 2-way out-of-order superscalar architecture and consists of all the Design Documents, Testbenches and Hardware Descriptions in **VHDL**

### Instruction Set Architecture Specification

It is the same as **26** instructions supported by the [**RISC_Pipelined**](https://github.com/TheKartikSinghal/RISC_Pipelined.git), their encoding can be found in the [Project Statement](SuperScalar_project_statement.pdf) for the pipelined processor.

## Supporting Programs
### Assembler
A ISA to Machine Code assembler has been made to speed up the testing process. It has been designed in Python to convert any input program stored as  `.asm` into a sequence of machine level 16 bit word instructions stored in   ./`source.bin` . The source code for it can be found in `./assembler.py.` The assembler also provides support for both **inline** and **out of** **line comments** for documentation to be present in the `.asm` file.

To assemble the code for a file called `code.asm` in the same directory as `assembler.py` can be done in the following way.

````bash
python assembler.py code
````

### Bootloader
A simple program to load the assembled instructions into the processor's memory without manual intervention.

## Software Requirements and Setup
To speed-up testing and improvement iterations, the process of compilation and simulation has been moved from Quartus and ModelSim to [GHDL](https://github.com/ghdl/ghdl) and [GTKWave](http://gtkwave.sourceforge.net/).

### Installation Procedure for Linux Systems
- Run "sudo apt-get install ghdl gtkwave" on the terminal
- Clone this repository and cd to it
- Run "make" on the terminal which should compile and simulate the design and display the waveform.

### Utilizing Signal Reload feature of GTKWave
Unlike ModelSim, it is quite easy to save signals for re-use in GTKWave.
- Once you are satisfied with the current set of signals you have on the screen, simply go to File->Write Save File
- This will store the signals in the already included signals.gtkw file

## Contributors
- Aparna Agrawal
- Shravani Kode
- Snehaa Reddy
- Kartik Singhal