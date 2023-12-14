# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Revised - KH July 2019
# Measure Renamed, License Updated, and Code Cleaned - KH June 2020

# start the measure
class AddPackagedIceStorage < OpenStudio::Measure::EnergyPlusMeasure
  # human readable name
  def name
    'Add Packaged Ice Storage'
  end

  # human readable description
  def description
    'This measure removes the cooling coils in the model and replaces them with packaged air conditioning units with integrated ice storage.'
  end

  # human readable description of modeling approach
  def modeler_description
    "This measure applies to packaged single zone air conditioning systems or packaged variable air volume systems that were originally modeled with CoilSystem:Cooling:DX or AirLoopHVAC:UnitarySystem container objects. It adds a Coil:Cooling:DX:SingleSpeed:ThermalStorage coil object to each user-selected thermal zone and deletes the existing cooling coil.

    Users inputs are accepted for cooling coil size, ice storage size, system control method, modes of operation, and operating schedule.

    The measure requires schedule objects and performance curves from an included resource file TESCurves.idf. Output variables of typical interest are included as well."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    # # Add a delimiter for clarify
    # delimiter = OpenStudio::Measure::OSArgument.makeStringArgument('delimiter', false)
    # delimiter.setDisplayName('Select Coils to Replace:')
    # delimiter.setDefaultValue('-----------------------------------------------------------------')
    # args << delimiter

    # get existing dx coils for user selection
    coils = workspace.getObjectsByType('Coil:Cooling:DX:SingleSpeed'.to_IddObjectType)
    coils += workspace.getObjectsByType('Coil:Cooling:DX:TwoSpeed'.to_IddObjectType)
    coilhash = {}
    c = coils.sort { |a, b| a.getString(0).get <=> b.getString(0).get }
    c.each do |coil|
      c_name = coil.name.to_s
      coilhash[c_name] = true
    end

    # make boolean argument for selecting cooling coils to replace
    coilhash.each do |k, v|
      coil_selection = OpenStudio::Measure::OSArgument.makeBoolArgument(k, true)
      coil_selection.setDisplayName(k)
      coil_selection.setDefaultValue(v)
      coil_selection.setDescription('Replace this coil?')
      args << coil_selection
    end

    ice_cap = OpenStudio::Measure::OSArgument.makeStringArgument('ice_cap', true)
    ice_cap.setDisplayName('Input the ice storage capacity [ton-hours]')
    ice_cap.setDescription('To specify by coil, in alphabetical order, enter values for each separated by comma.')
    ice_cap.setDefaultValue('AutoSize')
    args << ice_cap

    size_mult = OpenStudio::Measure::OSArgument.makeStringArgument('size_mult', false)
    size_mult.setDisplayName('Enter a sizing multiplier to manually adjust the autosize results for ice tank capacities')
    size_mult.setDefaultValue('1.0')
    args << size_mult

    # make argument for control method
    ctl = OpenStudio::Measure::OSArgument.makeChoiceArgument('ctl', ['ScheduledModes', 'EMSControlled'], true)
    ctl.setDisplayName('Select ice storage control method')
    ctl.setDefaultValue('EMSControlled')
    args << ctl

    # obtain default schedule names in TESCurves.idf. This allows users to manually add schedules to the idf and be able to access them in OS or PAT
    source_idf = OpenStudio::IdfFile.load(OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/TESCurves.idf")).get
    schedules = source_idf.getObjectsByType('Schedule:Compact'.to_IddObjectType)
    schedule_names = OpenStudio::StringVector.new

    schedules.each do |sch|
      schedule_names << sch.name.to_s
    end

    # make argument for TES operating mode schedule
    sched = OpenStudio::Measure::OSArgument.makeChoiceArgument('sched', schedule_names, true)
    sched.setDisplayName('Select the operating mode schedule for the new TES coils')
    sched.setDescription('Use the fields below to set a simple daily ice charge/discharge schedule. Or, select from pre-defined options.')
    sched.setDefaultValue('Simple User Sched')
    args << sched

    # make arguement for weekend TES operation
    wknd = OpenStudio::Measure::OSArgument.makeBoolArgument('wknd', false)
    wknd.setDisplayName('Run TES on the weekends')
    wknd.setDescription('Select if building is occupied on weekends')
    wknd.setDefaultValue(true)
    args << wknd

    # make arguments for operating season
    season = OpenStudio::Measure::OSArgument.makeStringArgument('season', false)
    season.setDisplayName('Select season during which the ice cooling may be used')
    season.setDescription('Use MM/DD-MM/DD format')
    season.setDefaultValue('01/01-12/31')
    args << season

    # make arguments for simple charging period
    charge_start = OpenStudio::Measure::OSArgument.makeStringArgument('charge_start', false)
    charge_start.setDisplayName('Input start time for ice charge (hr:min)')
    charge_start.setDescription('Use 24 hour format')
    charge_start.setDefaultValue('22:00')
    args << charge_start

    charge_end = OpenStudio::Measure::OSArgument.makeStringArgument('charge_end', false)
    charge_end.setDisplayName('Input end time for ice charge (hr:min)')
    charge_end.setDescription('Use 24 hour format')
    charge_end.setDefaultValue('07:00')
    args << charge_end

    # make arguments for simple discharging period
    discharge_start = OpenStudio::Measure::OSArgument.makeStringArgument('discharge_start', false)
    discharge_start.setDisplayName('Input start time for ice discharge (hr:min)')
    discharge_start.setDescription("Use 24hour format.\nIf 'AutoSize' is selected for ice capacity, these inputs set an ice capacity sizing factor. Otherwise, these only affect discharging schedule.")
    discharge_start.setDefaultValue('12:00')
    args << discharge_start

    discharge_end = OpenStudio::Measure::OSArgument.makeStringArgument('discharge_end', false)
    discharge_end.setDisplayName('Input target end time for ice discharge (hr:min)')
    discharge_end.setDescription('Use 24 hour format')
    discharge_end.setDefaultValue('18:00')
    args << discharge_end

    args
    # end the arguments method
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # load required TESCurves.idf. This contains all the TES performance curves and default schedules
    source_idf = OpenStudio::IdfFile.load(OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/TESCurves.idf")).get

    # workspace.addObjects(idf_obj_vector) does not work here. Add each obj individually.
    source_idf.objects.each do |o|
      workspace.addObject(o)
    end
    runner.registerInfo("#{source_idf.objects.size} performance curves, schedule objects, and output variables were imported from 'TESCurves.idf'.\n\n")

    # assign user arguments to variables
    ice_cap = runner.getStringArgumentValue('ice_cap', user_arguments)                  # ice capacity value (in ton-hours)
    size_mult = runner.getStringArgumentValue('size_mult', user_arguments)              # size multiplier for ice tank capacity - use if autosize is excessively oversizing
    ctl = runner.getStringArgumentValue('ctl', user_arguments)                          # control method (schedule or EMS)
    sched = runner.getStringArgumentValue('sched', user_arguments)                      # select operating mode schedule (schedule objects located in resources\TESCurves.idf)
    wknd = runner.getBoolArgumentValue('wknd', user_arguments)                          # turn tes on/off for weekend operation
    season = runner.getStringArgumentValue('season', user_arguments)                    # set operating season for Simple User Sched
    charge_start = runner.getStringArgumentValue('charge_start', user_arguments)        # time ice charging begins
    charge_end = runner.getStringArgumentValue('charge_end', user_arguments)            # time ice charging ends
    discharge_start = runner.getStringArgumentValue('discharge_start', user_arguments)  # time ice discharge begins
    discharge_end = runner.getStringArgumentValue('discharge_end', user_arguments)      # time ice discharge ends

    # retrieve user selected coils and assign to vector
    coils = workspace.getObjectsByType('Coil:Cooling:DX:SingleSpeed'.to_IddObjectType)
    coils += workspace.getObjectsByType('Coil:Cooling:DX:TwoSpeed'.to_IddObjectType)
    coilhash = {}
    c = coils.sort { |a, b| a.getString(0).get <=> b.getString(0).get }
    c.each do |coil|
      c_name = coil.name.to_s
      coilhash[c_name] = true
    end

    coil_selection = []
    coilhash.each do |k, v|
      temp_var = runner.getBoolArgumentValue(k, user_arguments)
      coil_selection << k if temp_var
    end

    # create other useful variables
    replacement_count = 0                         # tracks number of coils replaced by measure
    time_size_factor = ''                         # sets Storage Capacity Sizing Factor {hr}
    discharge_cop = '63.6'                        # default COP for Ice Discharge
    curve_d_shr_ft = 'Discharge-SHR-fT-NREL'      # default curve for sensible heat ratio f(T) during ice discharge

    # convert string time values into floats for math comparisons
    # ds/de = discharge start/end, cs/ce = charge start/end
    ds = discharge_start.split(':')[0].to_f + (discharge_start.split(':')[1].to_f / 0.6)
    de = discharge_end.split(':')[0].to_f + (discharge_end.split(':')[1].to_f / 0.6)
    cs = charge_start.split(':')[0].to_f + (charge_start.split(':')[1].to_f / 0.6)
    ce = charge_end.split(':')[0].to_f + (charge_end.split(':')[1].to_f / 0.6)

    # #Check User Inputs and Define Variables
    hardcaps = []
    if ice_cap != 'AutoSize'
      if ice_cap == ''
        runner.registerWarning("No ice capacity was entered for 'User Input' selection, 'AutoSize' was used instead.")
        ice_cap = 'AutoSize'
      elsif ice_cap.split(',').size > 1
        runner.registerInfo('Ice storage tanks will be hardsized based on user inputs, assigned alphabetically.')
        ice_cap.split(',').each { |i| hardcaps.push((i.to_f * 0.0126608).to_s) }
        while hardcaps.size != coil_selection.size
          runner.registerInfo("No user-defined thermal storage capacity for #{coil_selection[hardcaps.size]}; unit will be AutoSized.")
          hardcaps.push('AutoSize')
        end
      else
        ice_cap = (ice_cap.to_f * 0.0126608).to_s # convert units from ton-hours to GJ
      end
    elsif sched == 'Simple User Sched'
      time_size_factor = ((de - ds) * size_mult.to_f).to_s
    elsif sched == 'TES Sched 2: 1-5 Peak'
      time_size_factor = (4.0 * size_mult.to_f).to_s
    elsif sched == 'TES Sched 3: 3-8 Peak'
      time_size_factor = (5.0 * size_mult.to_f).to_s
    elsif sched == 'TES Sched 4: GSS-T'
      time_size_factor = (3.0 * size_mult.to_f).to_s
    else
      time_size_factor = (4.0 * size_mult.to_f).to_s # sets default time size factor to 4 hours
    end

    # Check user schedule inputs and build schedule
    if sched == 'Simple User Sched'

      # find empty user input schedule object from TESCurves.idf import
      user_schedules = workspace.getObjectsByName('Simple User Sched')
      user_schedule = user_schedules[0]

      # check ice discharge times to ensure end occurs after start. Exit gracefully if it doesn't.
      if de < ds
        runner.registerError('Ice discharge end time occurs before the start time. If ice discharge is desired overnight, create a schedule object in ../resources/TESCurves.idf. Measure was not applied.')
        return false
      end

      # sets charge and discharge mode ** May be modified if Cool_Charge or Cool_Discharge modes become available
      charge_mode = 4
      discharge_mode = 5

      # format user input for cooling season values
      czn = season.split(/[\s-]/)
      cool_start = czn[0].to_s
      cool_end = czn[-1].to_s

      # set cooling season start periods
      a = 4 # index variable to ensure schedule is built properly under various conditions
      c = 3 # index variable to help ensure a weekday-only schedule is properly built

      if cool_start != '01/01'
        user_schedule.setString(2, "Through: #{cool_start}")
        user_schedule.setString(3, 'For: AllDays')
        user_schedule.setString(4, 'Until: 24:00')
        user_schedule.setString(5, '1')
        user_schedule.setString(7, 'For: AllDays')
        a = 8
        c = 7
      end

      # build user defined schedule object
      if cs > ce
        # assign times to schedule fields
        user_schedule.setString(a, "Until: #{charge_end}")
        user_schedule.setString(a + 1, charge_mode.to_s)
        user_schedule.setString(a + 2, "Until: #{discharge_start}")
        user_schedule.setString(a + 3, '1')
        user_schedule.setString(a + 4, "Until: #{discharge_end}")
        user_schedule.setString(a + 5, discharge_mode.to_s)
        user_schedule.setString(a + 6, "Until: #{charge_start}")
        user_schedule.setString(a + 7, '1')
        user_schedule.setString(a + 8, 'Until: 24:00')
        user_schedule.setString(a + 9, charge_mode.to_s)
        b = a + 10
      elsif charge_start != '00:00'
        user_schedule.setString(a, "Until: #{charge_end}")
        user_schedule.setString(a + 1, charge_mode.to_s)
        user_schedule.setString(a + 2, "Until: #{discharge_start}")
        user_schedule.setString(a + 3, '1')
        user_schedule.setString(a + 4, "Until: #{discharge_end}")
        user_schedule.setString(a + 5, discharge_mode.to_s)
        user_schedule.setString(a + 6, 'Until: 24:00')
        user_schedule.setString(a + 7, '1')
        b = a + 8
      else
        user_schedule.setString(a, "Until: #{charge_end}")
        user_schedule.setString(a + 1, charge_mode.to_s)
        user_schedule.setString(a + 2, "Until: #{discharge_start}")
        user_schedule.setString(a + 3, '1')
        user_schedule.setString(a + 4, "Until: #{discharge_end}")
        user_schedule.setString(a + 5, discharge_mode.to_s)
        user_schedule.setString(a + 6, 'Until: 24:00')
        user_schedule.setString(a + 7, '1')
        b = a + 8
      end

      # make weekend modification if necessary
      unless wknd
        user_schedule.setString(c, 'For: WeekDays')
        user_schedule.setString(b, 'For: Weekends')
        user_schedule.setString(b + 1, "Until: #{charge_end}")
        user_schedule.setString(b + 2, charge_mode.to_s)
        user_schedule.setString(b + 3, 'Until: 24:00')
        user_schedule.setString(b + 4, '1')
        b += 5
      end

      # complete cooling season schedule if not through 12/31
      if cool_end != '12/31'
        user_schedule.setString(c - 1, "Through: #{cool_end}")
        user_schedule.setString(b, 'Through: 12/31')
        user_schedule.setString(b + 1, 'For: AllDays')
        user_schedule.setString(b + 2, 'Until: 24:00')
        user_schedule.setString(b + 3, '1')
      end
    end

    # find objects of interest in the model (used to identify container objects, air loops, and thermal zones)
    cooling_coil_systems = workspace.getObjectsByType('CoilSystem:Cooling:DX'.to_IddObjectType)
    air_loops = workspace.getObjectsByType('AirLoopHVAC'.to_IddObjectType)
    branches = workspace.getObjectsByType('Branch'.to_IddObjectType)
    hvac_zone_mixers = workspace.getObjectsByType('AirLoopHVAC:ZoneMixer'.to_IddObjectType)
    zone_connections = workspace.getObjectsByType('ZoneHVAC:EquipmentConnections'.to_IddObjectType)
    unitary_generic_obj = workspace.getObjectsByType('AirLoopHVAC:UnitarySystem'.to_IddObjectType)
    node_lists = workspace.getObjectsByType('NodeList'.to_IddObjectType)

    # create vector of all cooling system container objects
    cooling_containers = OpenStudio::IdfObjectVector.new
    cooling_coil_systems.each do |coil_sys|
      if coil_selection.include?(coil_sys.getString(6).to_s)
        cooling_containers << coil_sys
      end
    end
    unitary_generic_obj.each do |unitary_sys|
      if coil_selection.include?(unitary_sys.getString(15).to_s)
        cooling_containers << unitary_sys
      end
    end

    # exit gracefully if original model does not have coilSystem:Cooling objects
    if cooling_containers.empty?
      runner.registerError('This measure only operates on the following EnergyPlus container objects: CoilSystem:Cooling:DX and AirLoopHVAC:UnitarySystem. Measure was not applied.')
    end

    # create TES object string template for use in replacing existing coils; incorporates user input variables
    new_tes_string =
      "Coil:Cooling:DX:SingleSpeed:ThermalStorage,
        NAME PLACEHOLDER,        !- Name
        ALWAYS_ON,               !- Availability Schedule Name
        #{ctl},                  !- Operating Mode Control Method
        #{sched},                !- Operation Mode Control Schedule Name
        Ice,                     !- Storage Type
        ,                        !- User Defined Fluid Type
        ,                        !- Fluid Storage Volume {m3}
        AutoSize,                !- Ice Storage Capacity {GJ}
        #{time_size_factor},     !- Storage Capacity Sizing Factor {hr}
        AMBIENT NODE,            !- Storage Tank Ambient Temperature Node Name
        7.913,                   !- Storage Tank to Ambient U-value Times Area Heat Transfer Coefficient {W/K}
        ,                        !- Fluid Storage Tank Rating Temperature {C}
        AutoSize,                !- Rated Evaporator Air Flow Rate {m3/s}
        EVAP IN NODE,            !- Evaporator Air Inlet Node Name
        EVAP OUT NODE,           !- Evaporator Air Outlet Node Name
        Yes,                     !- Cooling Only Mode Available
        AutoSize,                !- Cooling Only Mode Rated Total Evaporator Cooling Capacity {W}  **IB40 Limits: 10551 W (3 ton) to 70337 W (20 ton)**
        0.7,                     !- Cooling Only Mode Rated Sensible Heat Ratio
        3.23372055845678,        !- Cooling Only Mode Rated COP {W/W}
        Cool-Cap-fT,             !- Cooling Only Mode Total Evaporator Cooling Capacity Function of Temperature Curve Name
        ConstantCubic,           !- Cooling Only Mode Total Evaporator Cooling Capacity Function of Flow Fraction Curve Name
        Cool-EIR-fT,             !- Cooling Only Mode Energy Input Ratio Function of Temperature Curve Name
        ConstantCubic,           !- Cooling Only Mode Energy Input Ratio Function of Flow Fraction Curve Name
        Cool-PLF-fPLR,           !- Cooling Only Mode Part Load Fraction Correlation Curve Name
        Cool-SHR-fT,             !- Cooling Only Mode Sensible Heat Ratio Function of Temperature Curve Name
        Cool-SHR-fFF,            !- Cooling Only Mode Sensible Heat Ratio Function of Flow Fraction Curve Name
        No,                      !- Cooling And Charge Mode Available
        AutoSize,                !- Cooling And Charge Mode Rated Total Evaporator Cooling Capacity
        1.0,                     !- Cooling And Charge Mode Capacity Sizing Factor
        AutoSize,                !- Cooling And Charge Mode Rated Storage Charging Capacity
        0.86,                    !- Cooling And Charge Mode Storage Capacity Sizing Factor
        0.7,                     !- Cooling And Charge Mode Rated Sensible Heat Ratio
        3.66668443E+00,          !- Cooling And Charge Mode Cooling Rated COP
        2.17,                    !- Cooling And Charge Mode Charging Rated COP
        CoolCharge-Cool-Cap-fT,  !- Cooling And Charge Mode Total Evaporator Cooling Capacity Function of Temperature Curve Name
        ConstantCubic,           !- Cooling And Charge Mode Total Evaporator Cooling Capacity Function of Flow Fraction Curve Name
        CoolCharge-Cool-EIR-fT,  !- Cooling And Charge Mode Evaporator Energy Input Ratio Function of Temperature Curve Name
        ConstantCubic,           !- Cooling And Charge Mode Evaporator Energy Input Ratio Function of Flow Fraction Curve Name
        Cool-PLF-fPLR,           !- Cooling And Charge Mode Evaporator Part Load Fraction Correlation Curve Name
        CoolCharge-Charge-Cap-fT,!- Cooling And Charge Mode Storage Charge Capacity Function of Temperature Curve Name
        ConstantCubic,           !- Cooling And Charge Mode Storage Charge Capacity Function of Total Evaporator PLR Curve Name
        CoolCharge-Charge-EIR-fT,!- Cooling And Charge Mode Storage Energy Input Ratio Function of Temperature Curve Name
        ConstantCubic,           !- Cooling And Charge Mode Storage Energy Input Ratio Function of Flow Fraction Curve Name
        ConstantCubic,           !- Cooling And Charge Mode Storage Energy Part Load Fraction Correlation Curve Name
        Cool-SHR-fT,             !- Cooling And Charge Mode Sensible Heat Ratio Function of Temperature Curve Name
        Cool-SHR-fFF,            !- Cooling And Charge Mode Sensible Heat Ratio Function of Flow Fraction Curve Name
        No,                      !- Cooling And Discharge Mode Available
        ,                        !- Cooling And Discharge Mode Rated Total Evaporator Cooling Capacity {W}
        ,                        !- Cooling And Discharge Mode Evaporator Capacity Sizing Factor
        ,                        !- Cooling And Discharge Mode Rated Storage Discharging Capacity {W}
        ,                        !- Cooling And Discharge Mode Storage Discharge Capacity Sizing Factor
        ,                        !- Cooling And Discharge Mode Rated Sensible Heat Ratio
        ,                        !- Cooling And Discharge Mode Cooling Rated COP {W/W}
        ,                        !- Cooling And Discharge Mode Discharging Rated COP {W/W}
        ,                        !- Cooling And Discharge Mode Total Evaporator Cooling Capacity Function of Temperature Curve Name
        ,                        !- Cooling And Discharge Mode Total Evaporator Cooling Capacity Function of Flow Fraction Curve Name
        ,                        !- Cooling And Discharge Mode Evaporator Energy Input Ratio Function of Temperature Curve Name
        ,                        !- Cooling And Discharge Mode Evaporator Energy Input Ratio Function of Flow Fraction Curve Name
        ,                        !- Cooling And Discharge Mode Evaporator Part Load Fraction Correlation Curve Name
        ,                        !- Cooling And Discharge Mode Storage Discharge Capacity Function of Temperature Curve Name
        ,                        !- Cooling And Discharge Mode Storage Discharge Capacity Function of Flow Fraction Curve Name
        ,                        !- Cooling And Discharge Mode Storage Discharge Capacity Function of Total Evaporator PLR Curve Name
        ,                        !- Cooling And Discharge Mode Storage Energy Input Ratio Function of Temperature Curve Name
        ,                        !- Cooling And Discharge Mode Storage Energy Input Ratio Function of Flow Fraction Curve Name
        ,                        !- Cooling And Discharge Mode Storage Energy Part Load Fraction Correlation Curve Name
        ,                        !- Cooling And Discharge Mode Sensible Heat Ratio Function of Temperature Curve Name
        ,                        !- Cooling And Discharge Mode Sensible Heat Ratio Function of Flow Fraction Curve Name
        Yes,                     !- Charge Only Mode Available
        AutoSize,                !- Charge Only Mode Rated Storage Charging Capacity {W}
        0.8,                     !- Charge Only Mode Capacity Sizing Factor
        3.09,                    !- Charge Only Mode Charging Rated COP {W/W}
        ChargeOnly-Cap-fT,       !- Charge Only Mode Storage Charge Capacity Function of Temperature Curve Name
        ChargeOnly-EIR-fT,       !- Charge Only Mode Storage Energy Input Ratio Function of Temperature Curve Name
        Yes,                     !- Discharge Only Mode Available
        AutoSize,                !- Discharge Only Mode Rated Storage Discharging Capacity {W}
        1.37,                    !- Discharge Only Mode Capacity Sizing Factor
        0.64,                    !- Discharge Only Mode Rated Sensible Heat Ratio
        #{discharge_cop},        !- Discharge Only Mode Rated COP {W/W}
        Discharge-Cap-fT,        !- Discharge Only Mode Storage Discharge Capacity Function of Temperature Curve Name
        Discharge-Cap-fFF,       !- Discharge Only Mode Storage Discharge Capacity Function of Flow Fraction Curve Name
        ConstantBi,              !- Discharge Only Mode Energy Input Ratio Function of Temperature Curve Name
        ConstantCubic,           !- Discharge Only Mode Energy Input Ratio Function of Flow Fraction Curve Name
        ConstantCubic,           !- Discharge Only Mode Part Load Fraction Correlation Curve Name
        #{curve_d_shr_ft},       !- Discharge Only Mode Sensible Heat Ratio Function of Temperature Curve Name
        Discharge-SHR-fFF,       !- Discharge Only Mode Sensible Heat Ratio Function of Flow Fraction Curve Name
        0.0,                     !- Ancillary Electric Power {W}
        2.0,                     !- Cold Weather Operation Minimum Outdoor Air Temperature {C}
        0.0,                     !- Cold Weather Operation Ancillary Power {W}
        CONDENSER INLET NODE,    !- Condenser Air Inlet Node Name
        CONDENSER OUTLET NODE,   !- Condenser Air Outlet Node Name
        autocalculate,           !- Condenser Design Air Flow Rate {m3/s}
        1.25,                    !- Condenser Air Flow Sizing Factor
        AirCooled,               !- Condenser Type
        ,                        !- Evaporative Condenser Effectiveness {dimensionless}
        ,                        !- Evaporative Condenser Pump Rated Power Consumption {W}
        ,                        !- Basin Heater Capacity {W/K}
        ,                        !- Basin Heater Setpoint Temperature {C}
        ,                        !- Basin Heater Availability Schedule Name
        ,                        !- Supply Water Storage Tank Name
        ,                        !- Condensate Collection Water Storage Tank Name
        ,                        !- Storage Tank Plant Connection Inlet Node Name
        ,                        !- Storage Tank Plant Connection Outlet Node Name
        ,                        !- Storage Tank Plant Connection Design Flow Rate {m3/s}
        ,                        !- Storage Tank Plant Connection Heat Transfer Effectiveness
        ,                        !- Storage Tank Minimum Operating Limit Fluid Temperature {C}
        ;                        !- Storage Tank Maximum Operating Limit Fluid Temperature {C}"
    # end of new TES coil string

    # #Begin Coil Replacement
    # iterate through all CoilSystem:Cooling objects and replace existing coils with TES coils
    coil_selection.each do |sel_coil|
      # get workspace object for selected coil from name
      sel_coil = workspace.getObjectsByName(sel_coil)[0]
      ice_cap = hardcaps[replacement_count] unless hardcaps.empty?

      # get coil type in order to find get appropriate field keys
      # fields of interest: (0 - Max Cap, 1 - Rated COP, 2 - Inlet Node, 3 - Outlet Node)
      field_names = [] # may not be required. Check scope in Ruby documentation
      sel_type = sel_coil.iddObject.type.valueDescription.to_s
      case sel_type
      when 'Coil:Cooling:DX:SingleSpeed'
        field_names = ['Gross Rated Total Cooling Capacity', 'Gross Rated Cooling COP',
                       'Air Inlet Node Name', 'Air Outlet Node Name']
      when 'Coil:Cooling:DX:TwoSpeed'
        field_names = ['High Speed Gross Rated Total Cooling Capacity', 'High Speed Gross Rated Cooling COP',
                       'Air Inlet Node Name', 'Air Outlet Node Name']
      end

      # get field indices associated with desired keys
      keys = []
      field_names.each do |fn|
        keys << sel_coil.iddObject.getFieldIndex(fn).to_i
      end

      # get old coil name and create new coil name
      old_coil_name = sel_coil.getString(0).to_s
      utss_name = "UTSS Coil #{replacement_count}"

      # grab inlet and outlet air nodes form selected coil
      inlet = sel_coil.getString(keys[2]).to_s
      outlet = sel_coil.getString(keys[3]).to_s

      # update inlet and outlet node names - not needed possibly add later if names become confusing

      # create local ambient node
      idf_oa_ambient = OpenStudio::IdfObject.new('OutdoorAir:Node'.to_IddObjectType)
      ws_oa_ambient = workspace.addObject(idf_oa_ambient)
      oa_ambient = ws_oa_ambient.get
      oa_ambient.setString(0, "#{utss_name} OA Ambient Node")

      # create new condenser inlet node
      idf_condenser_inlet = OpenStudio::IdfObject.new('OutdoorAir:Node'.to_IddObjectType)
      ws_condenser_inlet = workspace.addObject(idf_condenser_inlet)
      condenser_inlet = ws_condenser_inlet.get
      condenser_inlet.setString(0, "#{utss_name} Condenser Inlet Node")

      # create new condenser inlet node
      idf_condenser_outlet = OpenStudio::IdfObject.new('OutdoorAir:Node'.to_IddObjectType)
      ws_condenser_outlet = workspace.addObject(idf_condenser_outlet)
      condenser_outlet = ws_condenser_outlet.get
      condenser_outlet.setString(0, "#{utss_name} Condenser Out Node")

      # create a new UTSS object
      idf_coil_object = OpenStudio::IdfObject.load(new_tes_string)
      utss_obj = idf_coil_object.get
      ws_tes_obj = workspace.addObject(utss_obj)
      utss = ws_tes_obj.get
      utss.setString(0, utss_name)

      # get indices for required utss fields - reused variable names, consider changing if confusing
      field_names = ['Evaporator Air Inlet Node Name', 'Evaporator Air Outlet Node Name',
                     'Storage Tank Ambient Temperature Node Name',
                     'Condenser Air Inlet Node Name', 'Condenser Air Outlet Node Name']

      keys = []
      field_names.each do |fn|
        keys << utss.iddObject.getFieldIndex(fn).to_i
      end

      # updated required fields in utss object
      utss.setString(keys[0], inlet)              # air inlet node
      utss.setString(keys[1], outlet)             # air outlet node
      utss.setString(keys[2], oa_ambient.name.to_s)         # outdoor ambient node
      utss.setString(keys[3], condenser_inlet.name.to_s)    # condenser inlet node
      utss.setString(keys[4], condenser_outlet.name.to_s)   # condenser outlet node
      utss.setString(7, ice_cap) # hardsized thermal storage capacity

      # copy old coil information over to TES object (use low-speed info for 2spd coils)
      case sel_coil.iddObject.name
      when 'Coil:Cooling:DX:SingleSpeed'
        runner.registerInfo("Grabing inputs for #{utss.getString(0)} from #{sel_coil.iddObject.name} object named #{sel_coil.getString(0)}")
        utss.setString(16, sel_coil.getString(2).get) # Gross Rated Total Cooling Capacity
        utss.setString(18, sel_coil.getString(4).get) # Gross Rated Cooling COP
        utss.setString(19, sel_coil.getString(10).get) # Total Cooling Capacity Function of Temperature Curve Name
        utss.setString(20, sel_coil.getString(11).get) # Total Cooling Capacity Function of Flow Fraction Curve Name
        utss.setString(21, sel_coil.getString(12).get) # Energy Input Ratio Function of Temperature Curve Name
        utss.setString(22, sel_coil.getString(13).get) # Energy Input Ratio Function of Flow Fraction Curve Name
        utss.setString(23, sel_coil.getString(14).get) # Part Load Fraction Correlation Curve Name
      when 'Coil:Cooling:DX:TwoSpeed'
        runner.registerInfo("Grabing inputs for #{utss.getString(0)} from #{sel_coil.iddObject.name} object named #{sel_coil.getString(0)}")
        utss.setString(16, sel_coil.getString(16).get) # Low Speed Gross Rated Total Cooling Capacity
        utss.setString(18, sel_coil.getString(18).get) # Low Speed Gross Rated Cooling COP
        utss.setString(19, sel_coil.getString(22).get) # Low Speed Total Cooling Capacity Function of Temperature Curve Name
        utss.setString(20, sel_coil.getString(12).get) # Total Cooling Capacity Function of Flow Fraction Curve Name
        utss.setString(21, sel_coil.getString(23).get) # Low Speed Energy Input Ratio Function of Temperature Curve Name
        utss.setString(22, sel_coil.getString(14).get) # Energy Input Ratio Function of Flow Fraction Curve Name
        utss.setString(23, sel_coil.getString(15).get) # Part Load Fraction Correlation Curve Name
      end

      # identify container object in which the coil is used
      cooling_containers.each do |cont|
        case cont.iddObject.type.valueDescription.to_s
        when 'CoilSystem:Cooling:DX'
          if cont.getString(6).to_s == old_coil_name
            cont.setString(5, 'Coil:Cooling:DX:SingleSpeed:ThermalStorage')
            cont.setString(6, utss_name)
            break
          end
        when 'AirLoopHVAC:UnitarySystem'
          if cont.getString(15).to_s == old_coil_name
            cont.setString(14, 'Coil:Cooling:DX:SingleSpeed:ThermalStorage')
            cont.setString(15, utss_name)
            break
          end
        end
      end

      # remove old coil
      workspace.removeObject(sel_coil.handle)

      # increment replacement count
      replacement_count += 1

      ## Add EMS Controller Components
      # create EMS intended schedule sensor once
      if replacement_count == 1
        idf_sched_sensor = OpenStudio::IdfObject.new('EnergyManagementSystem:Sensor'.to_IddObjectType)
        ws_sched_sensor = workspace.addObject(idf_sched_sensor)
        new_sched_sensor = ws_sched_sensor.get
        new_sched_sensor.setString(0, 'TESIntendedSchedule')
        new_sched_sensor.setString(1, sched)
        new_sched_sensor.setString(2, 'Schedule Value')
      end

      # clean-up variable names for EMS purposes (no spaces allowed)
      u_name = utss_name.gsub(/\s/, '_')

      # add EMS sensor for TES control
      idf_sensor = OpenStudio::IdfObject.new('EnergyManagementSystem:Sensor'.to_IddObjectType)
      ws_sensor = workspace.addObject(idf_sensor)
      new_sensor = ws_sensor.get
      new_sensor.setString(0, "#{u_name}_sTES")
      new_sensor.setString(1, utss_name)
      new_sensor.setString(2, 'Cooling Coil Ice Thermal Storage End Fraction')

      # add EMS actuator for TES control
      idf_actuator = OpenStudio::IdfObject.new('EnergyManagementSystem:Actuator'.to_IddObjectType)
      ws_actuator = workspace.addObject(idf_actuator)
      new_actuator = ws_actuator.get
      new_actuator.setString(0, "#{u_name}_OpMode")
      new_actuator.setString(1, utss_name)
      new_actuator.setString(2, 'Coil:Cooling:DX:SingleSpeed:ThermalStorage')
      new_actuator.setString(3, 'Operating Mode')

      # add Global Variable to track min SOC from previous use
      idf_gvar = OpenStudio::IdfObject.new('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
      ws_gvar = workspace.addObject(idf_gvar)
      new_gvar = ws_gvar.get
      new_gvar.setString(0, "#{u_name}_MinSOC")

      # add EMS program for TES control
      program_string = "
      EnergyManagementSystem:Program,
        #{u_name}_Control,      !- Name
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

      idf_program = OpenStudio::IdfObject.load(program_string)
      idf_prgm = idf_program.get
      workspace.addObject(idf_prgm)

      # add EMS program calling manager for TES control
      idf_pcm = OpenStudio::IdfObject.new('EnergyManagementSystem:ProgramCallingManager'.to_IddObjectType)
      ws_pcm = workspace.addObject(idf_pcm)
      new_pcm = ws_pcm.get
      new_pcm.setString(0, "#{u_name}_TES_PrgmCallMgr")
      new_pcm.setString(1, 'AfterPredictorAfterHVACManagers')
      new_pcm.setString(2, "#{u_name}_Control")

      # register info
      # Coil replaced, Coil Added, EMS Program Added
      runner.registerInfo("Coil '#{old_coil_name}' was replaced with a unitary thermal storage system named" \
                          "'#{utss.name}' with a capacity of #{ice_cap} GJ.\n")
      # end of coil replacement routine
    end

    # additional output for schedule verification
    runner.registerInfo("The user-selected schedule for the ice unit operation is:\n\n#{user_schedule}")

    # register initial and final conditions
    runner.registerInitialCondition("The building started with #{cooling_containers.size} cooling coils.")
    runner.registerFinalCondition("A total of #{replacement_count} cooling coils were replaced with thermal storage coil systems.")
    true
  end
end

# register the measure to be used by the application
AddPackagedIceStorage.new.registerWithApplication
