

###### (Automatically generated documentation)

# Add Central Ice Storage

## Description
This measure adds an ice storage tank to a chilled water loop for the purpose of thermal energy storage.

## Modeler Description
This measure adds the necessary components and performs required model articulations to add an ice thermal storage tank (ITS) to an existing chilled water loop. Special consideration is given to implementing configuration and control options. Refer to the ASHRAE CTES Design Guide or manufacturer applications guides for detailed implementation info. A user guide document is included in the docs folder of this measure to help translate design objectives into measure argument input values.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Select Energy Storage Objective:

**Name:** objective,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Select Upstream Device:
Partial Storage Only. See documentation for control implementation.
**Name:** upstream,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter Thermal Energy Storage Capacity for Ice Tank [ton-hours]:

**Name:** storage_capacity,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Select Thaw Process Indicator for Ice Storage:

**Name:** melt_indicator,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Select Loop:
Error: No Cooling Loop Found
**Name:** selected_loop,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Select Chiller:
Error: No Chiller Found
**Name:** selected_chiller,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter Chiller Sizing Factor:

**Name:** chiller_resize_factor,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter Chiller Max Capacity Limit During Ice Discharge:
Enter as a fraction of chiller capacity (0.0 - 1.0).
**Name:** chiller_limit,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Use Existing (Pre-Defined) Temperature Control Schedules
Use drop-down selections below.
**Name:** old,
**Type:** Boolean,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Select Pre-Defined Ice Availability Schedule

**Name:** ctes_av,
**Type:** Choice,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Select Pre-Defined Ice Tank Component Setpoint Schedule

**Name:** ctes_sch,
**Type:** Choice,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Select Pre-Defined Chiller Component Setpoint Schedule

**Name:** chill_sch,
**Type:** Choice,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Create New (Simple) Temperature Control Schedules
Use entry fields below. If Pre-Defined is also selected, these new schedules will be created but not applied.
**Name:** new,
**Type:** Boolean,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Loop Setpoint Temperature F:
This value replaces the existing loop temperature setpoint manager; the old manager will be disconnected but not deleted from the model.
**Name:** loop_sp,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter Intermediate Setpoint for Upstream Cooling Device During Ice Discharge F:
Partial storage only
**Name:** inter_sp,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Ice Charging Setpoint Temperature F:

**Name:** chg_sp,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Loop Design Temperature Difference F:
Enter numeric value to adjust selected loop settings.
**Name:** delta_t,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter Seasonal Availabity of Ice Storage:
Use MM/DD-MM/DD format
**Name:** ctes_season,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter Starting Time for Ice Discharge:
Use 24 hour format (HR:MM)
**Name:** discharge_start,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter End Time for Ice Discharge:
Use 24 hour format (HR:MM)
**Name:** discharge_end,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter Starting Time for Ice charge:
Use 24 hour format (HR:MM)
**Name:** charge_start,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter End Time for Ice charge:
Use 24 hour format (HR:MM)
**Name:** charge_end,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Allow Ice Discharge on Weekends

**Name:** wknds,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Select Reporting Frequency for New Output Variables
This will not change reporting frequency for existing output variables in the model.
**Name:** report_freq,
**Type:** Choice,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Test Demand Reponse Event

**Name:** dr,
**Type:** Boolean,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Select if a Load Add or Load Shed Event

**Name:** dr_add_shed,
**Type:** Choice,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter date of demand response event:
Use MM/DD format.
**Name:** dr_date,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter start time of demand response event:
Use 24 hour format (HR:MM)
**Name:** dr_time,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter duration of demand response event [hr]:

**Name:** dr_dur,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Allow chiller to back-up ice during DR event
Unselection may result in unmet cooling hours
**Name:** dr_chill,
**Type:** Boolean,
**Units:** ,
**Required:** false,
**Model Dependent:** false




