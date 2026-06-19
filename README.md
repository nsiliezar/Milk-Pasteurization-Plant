# Milk Pasteurization Plant - Industrial Automation Project

A simulated industrial control system for a six-stage milk pasteurization 
process. Built to demonstrate PLC programming, HMI development, and 
industrial communication protocols.

This project showcases the complete automation stack an industrial 
automation engineer would build: ladder logic and structured text control 
programs, a live HMI dashboard, and Modbus TCP/IP communication between 
all layers.

## Acknowledgment

This project was built with the help of Claude AI (Anthropic). Claude 
provided the domain knowledge of how a real milk pasteurization plant is 
structured and sequenced, knowledge I didn't have starting out, and 
co-wrote a significant portion of the structured text process control logic. 
I directed the architecture, built and wired the OpenPLC/Node-RED/Modbus 
integration myself, debugged every connection issue hands on, and validated 
the system end to end through hardware in the loop style testing.

I'm including this for transparency: AI-assisted development is increasingly 
part of real engineering workflows, and I think how you use a tool like this 
well to learn unfamiliar domains and accelerate implementation while still 
owning the integration and validation.

## Architecture

The system is built across two layers, communicating over Modbus TCP/IP:

[Node-RED HMI] <----Modbus TCP/IP----> [OpenPLC Runtime]
   (Laptop)                            (Raspberry Pi)

| Layer | Role | Platform |
|---|---|---|
| **OpenPLC Runtime** | Executes ladder logic / structured text control program for the 6-stage pasteurization process | Raspberry Pi |
| **Node-RED** | HMI dashboard - operator controls, live temperature gauges, plant status, alarms, and batch logging | Laptop |

Communication uses Modbus TCP/IP, with Node-RED acting as a Modbus

client reading and writing directly to OpenPLC's memory (coils, discrete

inputs, and registers) to drive the live dashboard.

  ## Tech Stack

- **OpenPLC Runtime** - open source PLC runtime executing IEC 61131-3 
  ladder logic and structured text
- **OpenPLC Editor** - used to develop and compile the control program
- **Node-RED** - flow-based HMI dashboard and Modbus client
- **Modbus TCP/IP** - industrial communication protocol linking HMI and PLC
- **Raspberry Pi** - hardware host running the OpenPLC runtime
- **IEC 61131-3 Structured Text** - used for the core process control 
  function block (temperature control, CIP sequencing, alarm logic)

  ## Process Overview

The control program simulates a six-stage milk pasteurization process:

1. **Reception** - Milk tanker arrival is detected, inlet valve opens, 
   and the reception pump transfers milk into one of two raw storage 
   tanks (T01 / T02), selectable via a tank selector switch.

2. **Storage & Agitation** - Each storage tank runs an agitator whenever 
   milk is present, keeping the product homogenized while awaiting 
   processing.

3. **Pre-Heating** - Milk is transferred to a balance tank, then a 
   booster pump feeds it through a pre-heater. A hot water valve 
   modulates to bring the milk to setpoint (40°C) before entering the 
   pasteurizer.

4. **Pasteurization (HTST)** - The pre-heated milk passes through the 
   High-Temperature Short Time pasteurizer. A heating valve raises the 
   product to 72°C, and a hold timer ensures the milk stays at 
   temperature for the required hold time. If temperature drops below 
   setpoint, a divert valve redirects the batch away from packaging.

5. **Cooling & Storage** - Pasteurized milk is cooled via a chilled 
   water valve and stored in tank T03, monitored for high/low level 
   and temperature.

6. **CIP (Clean-In-Place)** - A multi-step automated cleaning sequence 
   (rinse → caustic wash → acid wash → final rinse) that can be 
   triggered between batches to clean the process lines.

Throughout all stages, the system includes:
- **Alarm logic** for high/low temperature faults, valve feedback 
  mismatches, and timeout conditions
- **Plant state machine** managing Startup → Running → Alarm → Stopped 
  transitions
- **E-Stop logic** that immediately de-energizes all outputs
- **Batch logging** recording timestamp, pasteurization temperatures, 
  and pass/fail result for each batch

- ## Screenshots

### Ladder Logic - Full Control Program
![ladder Logic](openplc/ladder-logic/milk_Pasteurization_plant_ladder_diagram_full.png)

### Process Control - Variable Table
![Process Control variable table](openplc/variable-table/ProcessControl_variable_table_full.png)
### Tank Level Test Program - Variable Table
![Tank levelvariable table](openplc/variable-table/TankLevel_variable_table_full.png)
### Node-RED HMI Dashboard
[View Node-RED HMI Dashboard (PDF)](node-red/flows/Node-RED_Dashboard.pdf)

## Testing Methodology

The control program was compiled without errors and successfully deployed 
to the OpenPLC runtime on a Raspberry Pi. Communication between Node-RED 
and OpenPLC over Modbus TCP/IP was confirmed working. HMI controls write 
correctly to PLC memory and PLC status reads back to the dashboard in 
real time.

**What this confirms:**
- The ladder logic and structured text compile and run without errors
- Modbus TCP/IP communication is correctly configured and functional 
  end to end between HMI and PLC
- Variable addressing and memory mapping are correct

## Repository Structure

Milk-Pasteurization-Plant/
├── README.md
├── docs/screenshots/
├── openplc/
│   ├── ladder-logic/
│   └── variable-table/
└── node-red/flows/

## What I Learned

This project took me through the full lifecycle of building a real PLC 
control system from scratch. not a tutorial exercise, but an original 
process I designed, programmed, wired together, and debugged end to end.

**Resources I used to get here:**
- *PLC Programming with the Raspberry Pi and the OpenPLC Project* (book)- 
  my starting point for understanding OpenPLC fundamentals
- OpenPLC Editor and Runtime documentation
- Node-RED documentation and community flow examples
- Raspberry Pi command line (SSH, networking, file system navigation)
- Claude AI - for domain knowledge and Structured Text drafting (see 
  Acknowledgment above)
- GitHub - learning how to structure and document a project for the 
  first time

**Key technical takeaways:**
- **Modbus addressing conventions** - understanding how OpenPLC maps 
  physical I/O versus Modbus slave I/O (e.g. `%QX0.x` for local outputs 
  vs. `%IX100.x` for Modbus-mapped inputs), and how address conflicts 
  between unrelated outputs can cause one control to silently trigger 
  another
- **OpenPLC variable declaration rules** - variables must be declared 
  exclusively in the variable table, not duplicated in Structured Text 
  `VAR` blocks, or the compiler fails
- **Function Blocks vs. Programs** - only Function Blocks can be 
  instantiated and reused inside ladder rungs, which shaped how the core 
  process control logic was structured
- **Debugging a live Modbus connection** - diagnosing connection failures 
  by checking IP configuration, firewall rules, and slave/master roles 
  between systems
- **The difference between "code compiles" and "process is validated"** - 
  and being able to clearly state what was and wasn't proven through 
  testing
- **Working across a full toolchain** - this was my first time using 
  OpenPLC, Node-RED, the Raspberry Pi command line, and GitHub together 
  on one project. Each tool had its own learning curve, and a lot of the 
  real work was figuring out how they were supposed to talk to each other.
  
Beyond any single technical skill, this project taught me what it actually 
takes to carry something from an idea through to a working system. Almost 
nothing worked on the first attempt; wrong Modbus addresses, address 
conflicts, compiler errors, connection failures. The project only 
moved forward because I kept isolating each problem, testing one change 
at a time, and verifying it before moving to the next. That habit of 
working a problem systematically until it's actually solved is the skill I'm most 
confident I can take into a real job.

