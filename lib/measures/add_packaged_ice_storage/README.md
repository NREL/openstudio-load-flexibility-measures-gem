# Guide for the Add Packaged Ice Storage Measure

## Description
This measure removes the cooling coils in the model and replaces them with packaged air conditioning units with integrated ice storage.

## Modeler Description
This measure applies to packaged single zone air conditioning systems or packaged variable air volume systems that were originally modeled with *CoilSystem:Cooling:DX* or *AirLoopHVAC:UnitarySystem* container objects. It adds a *Coil:Cooling:DX:SingleSpeed:ThermalStorage* coil object to each user-selected thermal zone and deletes the existing cooling coil.

Users inputs are accepted for cooling coil size, ice storage size, system control method, modes of operation, and operating schedule.

The measure requires schedule objects and performance curves from an included resource file TESCurves.idf. Output variables of typical interest are included as well.

## Measure Type
EnergyPlus Measure

## Application
This measure is built to simulate packaged ice storage units which integrate with packaged single zone AC units (eg. RTUs). An EnergyPlus object was created in 2013 to model this system, but it is not currently available in OpenStudio.

## Requirements
- Existing OpenStudio model with PVAV or PSZAC HVAC
- Original HVAC must use *CoilSystem:Cooling:DX* or *AirLoopHVAC:UnitarySystem* container objects
- "TESCurves.idf" resource file

## Limitations
- The measure **may** or **may not** properly replace the cooling coils in a VAV system, depending on the way the original HVAC model was built (container object dependent).
- If AutoSizing produces over/under-sized ice storage capacities, an adjustment multiplier is available. This multiplier will be applied to all AutoSized ice units.
- Cooling and Discharge Mode is currently unavailable due to the lack of available performance curves in the referenced EnergyPlus 9.3 example file.
- Cooling and Charge Mode is currently unavailable due to the lack of available performance curves in the referenced EnergyPlus 9.3 example file.

## How the Measure Works
The measure works by replacing user-selected single-speed and two-speed cooling coils (all applicable coils are pre-selected by default) with *Coil:Cooling:DX:SingleSpeed:ThermalStorage* objects. These TES units may be AutoSized, or hard-sized

An Energy Management System (EMS) program is created for each new TES coil. The default controller turns ice charging and discharging on/off based on ice storage tank end fraction (state of charge) and user-defined operating schedule. If users desire advanced control strategies, the EMS code may be modified directly in the "measure.rb" file (line 663 ff.). A built-in Schedule Modes controller is also available.

Whether EMS Control or Schedule Modes are used, a charge/discharge schedule is required. The default is a simple schedule created by user inputs. Ice storage capacity is based on the ice discharge window.

### TES Coil Operating Schedules
- *Simple User Sched* - Default. Builds schedule from user inputs.
- *TES Sched 1: TES Off* - Useful for creating a baseline case.
- *TES Sched 2: 1-5 Peak* - Discharges ice between 1:00-5:00 pm, Charges from midnight to 7 am.
- *TES Sched 3: 3-8 Peak* - Discharges ice between 3:00-8:00 pm, Charges from midnight to 7 am.
- *Rate Sched: GSS-T* - Aligns ice discharge to Sacramento's 2018 GSS-T electricity rate plan peak hours.

More complex custom schedules may be added to "TESCurves.idf".

### TES Coil Operating Modes
- 0: Off
- 1: Cooling Only (Ice tank is bypassed, state of charge is tracked)
- 2: Cooling and Charge (Ice charging simultaneous with zone cooling) - **UNAVAILABLE**
- 3: Cooling and Discharge (Zone cooling from both ice and AC cooling coil) - **UNAVAILABLE**
- 4: Charge Only (No zone cooling provided during ice charge)
- 5: Discharge Only (Zone cooling from ice only)

### Default EMS Controller for each Coil
    EnergyManagementSystem:Program,
      #{u_name}_Control,
      SET #{u_name}_OpMode = TESIntendedSchedule,
      IF CurrentEnvironment == 1,
        SET #{u_name}_MinSOC = 1,
      ENDIF,
      IF (#{u_name}_OpMode == 5),
        IF ( #{u_name}_sTES < 0.05 ),
          SET #{u_name}_OpMode = 1,
        ENDIF,
        SET #{u_name}_MinSOC = #{u_name}_sTES,
      ENDIF,
      IF (#{u_name}_OpMode == 4),
        IF ( #{u_name}_sTES > 0.99 ),
          SET #{u_name}_OpMode = 1,
        ENDIF,
      ENDIF;"

where

    "z_name" is the zone name
    "TESIntendedSchedule" obtains the scheduled coil operating mode (0-5)
    "sTES" is the fractional state of charge of the ice tank (0-1)
    "OpMode" sets the operating mode of the coil
    "MinSOC" is the minimum state of charge of the ice tank at the end of the previous discharge period

### Performance Curve Selection
 Default curves are those used in EnergyPlus 9.3 example file "RetailPackagedTESCoil.idf". Performance curves may be added to "TESCurves.idf".

### Arguments and Defaults

#### Select applicable zones:
**Name:** coil_selection,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** true
**Default:** All Thermal Zones

#### Select ice storage capacity [ton-hours]
**Name:** ice_cap,
**Type:** Choice,
**Units:** ton-hours (refrigeration),
**Required:** true,
**Model Dependent:** false,
**Default:** Autosize

#### Enter a sizing multiplier to manually adjust the autosize results for ice tank capacities.
**Name:** size_mult
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false,
**Default:** 1.0

#### Select ice storage control method
**Name:** ctl,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false,
**Default:** EMS Controlled

#### Select the operating mode schedule for the new TES coils
**Name:** sched,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false,
**Default:** Simple User Sched

#### Run TES on the weekends?
**Name:** wknd,
**Type:** Boolean,
**Units:** ,
**Required:** false,
**Model Dependent:** false,
**Default:** true

#### Select season during which the ice cooling may be used:
**Name:** season,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false,
**Default:** 01/01-12/31

#### Input start time for ice charge (hr:min)
**Name:** charge_start,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false,
**Default:** 22:00

#### Input end time for ice charge (hr:min)
**Name:** charge_end,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false,
**Default:** 07:00

#### Input start time for ice discharge (hr:min)
**Name:** discharge_start,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false,
**Default:** 12:00

#### Input target end time for ice discharge (hr:min)
**Name:** discharge_end,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false,
**Default:** 18:00

## References
DOE (2020). *15.2.27 Packaged Thermal Storage Cooling Coil*. Engineering Reference, EnergyPlus Version 9.3.0 Documentation. Accessed June 16, 2020, from https://energyplus.net/documentation/.

DOE (2020). *1.41.39 Coil:Cooling:DX:SingleSpeed:ThermalStorage*. Input-Output Reference, EnergyPlus Version 9.3.0 Documentation. Accessed June 16, 2020, from https://energyplus.net/documentation/.

EnergyPlus 9.3.0 (2018). *RetailPackagedTESCoil.idf*. Example file included with software. Accessed June 16, 2020, from https://energyplus.net/downloads/.

IceEnergy. *Ice Bear 40 Product Information Sheet*. Accessed Jun 1, 2018 from
https://www.ice-energy.com/wp-content/uploads/2018/05/IB-40-ProductSheet-2018-US-D3.pdf

Kung, F., Deru, M., and Bonnema, E. (2013). *Evaluation Framework and Analyses for Thermal Energy Storage Integrated with Packaged Air Conditioning*. NREL/TP-5500-60415. Accessed June 27, 2018, from https://www.nrel.gov/docs/fy14osti/60415.pdf/.

Willis, R. and Parsonnet, B. (2010). *Energy Efficient TES Designs for Commercial DX Systems*, ASHRAE Transactions, Vol. 116, pt. 1, Orlando 2010.

___
###### Author: Karl Heine, January 2019; Revised June 2020
