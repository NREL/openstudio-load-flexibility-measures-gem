# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# Measure distributed under NREL Copyright terms, see LICENSE.md file.

# Author: Karl Heine
# Date: December 2019 - March 2020

# References:
# EnergyPlus InputOutput Reference, Sections:
# EnergyPlus Engineering Reference, Sections:

# start the measure
class AddCentralHPWHForLoadFlexibility < OpenStudio::Measure::ModelMeasure
  require 'openstudio-standards'

  # human readable name
  def name
    # Measure name should be the title case of the class name.
    'flexible_domestic_hot_water'
  end

  # human readable description
  def description
    'This measure adds or replaces existing domestic hot water heater with air source heat pump system and ' \
           'allows for the addition of multiple daily flexible control time windows. The heater/tank system may ' \
           'charge at maximum capacity up to an elevated temperature, or float without any heat addition for a ' \
           'specified timeframe down to a minimum tank temperature.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure allows selection between three heat pump water heater modeling approaches in EnergyPlus.' \
           'The user may select between the pumped-condenser or wrapped-condenser objects. They may also elect to ' \
           'use a simplified calculation which does not use the heat pump objects, but instead used an electric ' \
           'resistance heater and approximates the equivalent electrical input that would be required from a heat ' \
           "pump. This expedites simulation at the expense of accuracy. \n" \
           'The flexibility of the system is based on user-defined temperatures and times, which are converted into ' \
           'schedule objects. There are four flexibility options. (1) None: normal operation of the DHW system at ' \
           'a fixed tank temperature setpoint. (2) Charge - Heat Pump: the tank is charged to a maximum temperature ' \
           'using only the heat pump. (3) Charge - Electric: the tank is charged using internal electric resistance ' \
           'heaters to a maximum temperature. (4) Float: all heating elements are turned-off for a user-defined time ' \
           'period unless the tank temperature falls below a minimum value. The heat pump will be prioritized in a ' \
           "low tank temperature event, with the electric resistance heaters serving as back-up. \n"
    'Due to the heat pump interaction with zone conditioning as well as tank heating, users may experience ' \
    'simulation errors if the heat pump is too large and placed in an already conditioned zoned. Try using ' \
    'multiple smaller units, modifying the heat pump location within the model, or adjusting the zone thermo' \
    'stat constraints. Use mulitiple instances of the measure to add multiple heat pump water heaters. '
  end

  ## USER ARGS ---------------------------------------------------------------------------------------------------------
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # create argument for removal of existing water heater tanks on selected loop
    remove_wh = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_wh', true)
    remove_wh.setDisplayName('Remove existing water heater on selected loop?')
    remove_wh.setDescription('')
    remove_wh.setDefaultValue(true)
    args << remove_wh

    # find available plant loops (heating)
    loop_names = []

    unless model.getPlantLoops.empty?
      loops = model.getPlantLoops
      loops.each do |lp|
        unless lp.sizingPlant.loopType.empty?
          next unless lp.sizingPlant.loopType.to_s == 'Heating'
          loop_names << lp.name.to_s
        end
      end
    end

    loop_names << 'Error: No Service Water Loop Found' if loop_names.empty?

    # create argument for loop selection
    loop = OpenStudio::Measure::OSArgument.makeChoiceArgument('loop', loop_names.sort, true)
    loop.setDisplayName('Select hot water loop')
    loop.setDescription('The water tank will be placed on the supply side of this loop.')
    loop.setDefaultValue(loop_names.sort[0])
    args << loop

    # find available spaces for heater location
    zone_names = []

    unless model.getThermalZones.empty?
      zones = model.getThermalZones
      zones.each do |zn|
        zone_names << zn.name.to_s
      end
      zone_names.sort!
    end

    zone_names << 'Error: No Thermal Zones Found' if zone_names.empty?

    # create argument for thermal zone selection (location of water heater)
    zone = OpenStudio::Measure::OSArgument.makeChoiceArgument('zone', zone_names, true)
    zone.setDisplayName('Select thermal zone')
    zone.setDescription('This is where the water heater tank will be placed')
    zone.setDefaultValue(zone_names[0])
    args << zone

    # create argument for water heater type
    type = OpenStudio::Measure::OSArgument.makeChoiceArgument('type',
                                                              ['PumpedCondenser', 'WrappedCondenser', 'Simplified'], true)
    type.setDisplayName('Select heat pump water heater type')
    type.setDescription('')
    type.setDefaultValue('PumpedCondenser')
    args << type

    # find largest current water heater volume - if any mixed tanks are already present. Default is 80 gal.
    default_vol = 80.0 # gal

    wheaters = if !model.getWaterHeaterMixeds.empty?
                 model.getWaterHeaterMixeds
               else
                 []
               end

    unless wheaters.empty?
      wheaters.each do |wh|
        unless wh.tankVolume.empty?
          default_vol = [default_vol, (wh.tankVolume.to_f / 0.0037854118).round(1)].max # convert m^3 to gal
        end
      end
    end

    # create argument for hot water tank volume
    vol = OpenStudio::Measure::OSArgument.makeDoubleArgument('vol', true)
    vol.setDisplayName('Set hot water tank volume')
    vol.setDescription('[gal]')
    vol.setDefaultValue(default_vol)
    args << vol

    # create argument for heat pump capacity
    cap = OpenStudio::Measure::OSArgument.makeDoubleArgument('cap', true)
    cap.setDisplayName('Set heat pump heating capacity')
    cap.setDescription('[kW]')
    cap.setDefaultValue((23.446 * (default_vol / 80.0)).round(1))
    args << cap

    # create argument for heat pump rated cop
    cop = OpenStudio::Measure::OSArgument.makeDoubleArgument('cop', true)
    cop.setDisplayName('Set heat pump rated COP (heating)')
    cop.setDescription('[-]')
    cop.setDefaultValue(2.8)
    args << cop

    # create argument for electric backup capacity
    bu_cap = OpenStudio::Measure::OSArgument.makeDoubleArgument('bu_cap', true)
    bu_cap.setDisplayName('Set electric backup heating capacity')
    bu_cap.setDescription('[kW]')
    bu_cap.setDefaultValue((23.446 * (default_vol / 80.0)).round(1))
    args << bu_cap

    # create argument for maximum tank temperature
    max_temp = OpenStudio::Measure::OSArgument.makeDoubleArgument('max_temp', true)
    max_temp.setDisplayName('Set maximum tank temperature')
    max_temp.setDescription('[F]')
    max_temp.setDefaultValue(160)
    args << max_temp

    # create argument for minimum float temperature
    min_temp = OpenStudio::Measure::OSArgument.makeDoubleArgument('min_temp', true)
    min_temp.setDisplayName('Set minimum tank temperature during float')
    min_temp.setDescription('[F]')
    min_temp.setDefaultValue(120)
    args << min_temp

    # create argument for deadband temperature difference between heat pump setpoint and electric backup
    db_temp = OpenStudio::Measure::OSArgument.makeDoubleArgument('db_temp', true)
    db_temp.setDisplayName('Set deadband temperature difference between heat pump and electric backup')
    db_temp.setDescription('[F]')
    db_temp.setDefaultValue(5)
    args << db_temp

    # find existing temperature setpoint schedules for water heater
    all_scheds = model.getSchedules
    temp_sched_names = []
    default_sched = '--Create New @ 140F--'
    default_ambient = ''
    all_scheds.each do |sch|
      next if sch.scheduleTypeLimits.empty?
      next unless sch.scheduleTypeLimits.get.unitType.to_s == 'Temperature'
      temp_sched_names << sch.name.to_s
      if !wheaters.empty? && (sch.name.to_s == wheaters[0].setpointTemperatureSchedule.get.name.to_s)
        default_sched = sch.name.to_s
      end
    end
    temp_sched_names = [default_sched] + temp_sched_names.sort

    # create argument for predefined schedule
    sched = OpenStudio::Measure::OSArgument.makeChoiceArgument('sched', temp_sched_names, true)
    sched.setDisplayName('Select reference tank setpoint temperature schedule')
    sched.setDescription('')
    sched.setDefaultValue(temp_sched_names[0])
    args << sched

    # define possible flex options
    flex_options = ['None', 'Charge - Heat Pump', 'Charge - Electric', 'Float']

    # create choice and string arguments for flex periods
    4.times do |n|
      flex = OpenStudio::Measure::OSArgument.makeChoiceArgument('flex' + n.to_s, flex_options, true)
      flex.setDisplayName("Daily Flex Period #{n + 1}:")
      flex.setDescription('Applies every day in the full run period.')
      flex.setDefaultValue('None')
      args << flex

      flex_hrs = OpenStudio::Measure::OSArgument.makeStringArgument('flex_hrs' + n.to_s, false)
      flex_hrs.setDisplayName('Use 24-Hour Format')
      flex_hrs.setDefaultValue('HH:MM - HH:MM')
      args << flex_hrs
    end

    args
  end
  ## END USER ARGS -----------------------------------------------------------------------------------------------------

  ## MEASURE RUN -------------------------------------------------------------------------------------------------------
  # Index:
  # => Argument Validation
  # => Controls: Heat Pump Heating Shedule
  # => Controls: Tank Electric Backup Heating Schedule
  # => Hardware
  # => Controls Modifications for Tank
  # => Report Output Variables

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    ## ARGUMENT VALIDATION ---------------------------------------------------------------------------------------------
    # Measure does not immedately return false upon error detection. Errors are accumulated throughout this selection
    # before exiting gracefully prior to measure execution.

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # report initial condition of model
    tanks_ic = model.getWaterHeaterMixeds.size + model.getWaterHeaterStratifieds.size
    hpwh_ic = model.getWaterHeaterHeatPumps.size + model.getWaterHeaterHeatPumpWrappedCondensers.size
    runner.registerInitialCondition("The building started with #{tanks_ic} water heater tank(s) and " \
                                    "#{hpwh_ic} heat pump water heater(s).")

    # create empty arrays and initialize variables for future use
    flex = []
    flex_type = []
    flex_hrs = []
    time_check = []
    hours = []
    minutes = []
    flex_times = []

    # assign the user inputs to variables
    remove_wh = runner.getBoolArgumentValue('remove_wh', user_arguments)
    loop = runner.getStringArgumentValue('loop', user_arguments)
    zone = runner.getStringArgumentValue('zone', user_arguments)
    type = runner.getStringArgumentValue('type', user_arguments)
    cap = runner.getDoubleArgumentValue('cap', user_arguments)
    cop = runner.getDoubleArgumentValue('cop', user_arguments)
    bu_cap = runner.getDoubleArgumentValue('bu_cap', user_arguments)
    vol = runner.getDoubleArgumentValue('vol', user_arguments)
    max_temp = runner.getDoubleArgumentValue('max_temp', user_arguments)
    min_temp = runner.getDoubleArgumentValue('min_temp', user_arguments)
    db_temp = runner.getDoubleArgumentValue('db_temp', user_arguments)
    sched = runner.getStringArgumentValue('sched', user_arguments)

    4.times do |n|
      flex << runner.getStringArgumentValue('flex' + n.to_s, user_arguments)
      flex_hrs << runner.getStringArgumentValue('flex_hrs' + n.to_s, user_arguments)
    end

    # check for error inputs
    if loop.include?('Error')
      runner.registerError('No service hot water loop was found. Measure did not run.')
    end

    if zone.include?('Error')
      runner.registerError('No thermal zone was found. Measure did not run.')
    end

    # check capacity, volume, and temps for reasonableness
    if cap < 5
      runner.registerWarning('HPWH heating capacity is less than 5kW ( 17kBtu/hr)')
    end

    if bu_cap < 5
      runner.registerWarning('Backup heating capaicty is less than 5kW ( 17kBtu/hr).')
    end

    if vol < 40
      runner.registerWarning('Tank has less than 40 gallon capacity; check heat pump sizing if model fails.')
    end

    if min_temp < 120
      runner.registerWarning('Minimum tank temperature is very low; consider increasing to at least 120F.')
      runner.registerWarning('Do not store water for long periods at temperatures below 135-140F as those ' \
                            'conditions facilitate the growth of Legionella.')
    end

    if max_temp > 180
      runner.registerWarning('Maximum charging temperature exceeded practical limits; reset to 180F.')
      max_temp = 180.0
    end

    if max_temp > 160
      runner.registerWarning("#{max_temp}F is above or near the limit of the HP performance curves. If the " \
                            'simulation fails with cooling capacity less than 0, you have exceeded performance ' \
                            'limits. Consider setting max temp to less than 160F.')
    end

    # check selected schedule and set flag for later use
    sched_flag = false # flag for either creating new (false) or modifying existing (true) schedule
    if sched == '--Create New @ 140F--'
      runner.registerInfo('No reference water heater temperature setpoint schedule was selected; a new one ' \
                          'will be created.')
    else
      sched_flag = true
      runner.registerInfo("#{sched} will be used as the water heater temperature setpoint schedule.")
    end

    # parse flex_hrs into hours and minuts arrays
    idx = 0
    flex_hrs.each do |fh|
      if flex[idx] != 'None'
        data = fh.split(/[-:]/)
        data.each { |e| e.delete!(' ') }
        if data[2] > data[0]
          flex_type << flex[idx]
          hours << data[0]
          hours << data[2]
          minutes << data[1]
          minutes << data[3]
        else
          flex_type << flex[idx]
          flex_type << flex[idx]
          hours << 0
          hours << data[2]
          hours << data[0]
          hours << 24
          minutes << 0
          minutes << data[3]
          minutes << data[1]
          minutes << 0
        end
      end
      idx += 1
    end

    # convert hours and minutes into OS:Time objects
    idx = 0
    hours.each do |h|
      flex_times << OpenStudio::Time.new(0, h.to_i, minutes[idx].to_i, 0)
      idx += 1
    end

    # flex.delete('None')

    runner.registerInfo("A total of #{idx / 2} flex periods will be added to the selected water heater setpoint schedule.")

    # exit gracefully if errors registered above
    return false unless runner.result.errors.empty?
    ## END ARGUMENT VALIDATION -----------------------------------------------------------------------------------------

    ## CONTROLS: HEAT PUMP HEATING TEMPERATURE SETPOINT SCHEDULE -------------------------------------------------------
    # This section creates the heat pump heating temperature setpoint schedule with flex periods
    # The tank schedule is created here

    # find or create new reference temperature schedule based on sched_flag value
    if sched_flag # schedule already exists and must be modified
      # converts the STRING into a MODEL OBJECT, same variable name
      sched = model.getScheduleRulesetByName(sched).get.clone.to_ScheduleRuleset.get
    else
      # must create new water heater setpoint temperature schedule at 140F
      sched = OpenStudio::Model::ScheduleRuleset.new(model, 60)
    end

    # rename and duplicate for later modification
    sched.setName('Heat Pump Heating Temperature Setpoint')
    sched.defaultDaySchedule.setName('Heat Pump Heating Temperature Setpoint Default')

    # tank_sched = sched.clone.to_ScheduleRuleset.get
    tank_sched = OpenStudio::Model::ScheduleRuleset.new(model, 60 - (db_temp / 1.8 + 2))
    tank_sched.setName('Tank Electric Heater Setpoint')
    tank_sched.defaultDaySchedule.setName('Tank Electric Heater Setpoint Default')

    # grab default day and time-value pairs for modification
    d_day = sched.defaultDaySchedule
    old_times = d_day.times
    old_values = d_day.values
    new_values = Array.new(flex_times.size, 2)

    # find existing values in reference schedule and grab for use in new-rule creation
    flex_times.size.times do |i|
      if i.even?
        n = 0
        old_times.each do |ot|
          new_values[i] = old_values[n] if flex_times[i] <= ot
          n += 1
        end
      elsif flex_type[(i / 2).floor] == 'Charge - Heat Pump'
        new_values[i] = OpenStudio.convert(max_temp, 'F', 'C').get
      elsif flex_type[(i / 2).floor] == 'Float' || flex_type[(i / 2).floor] == 'Charge - Electric'
        new_values[i] = OpenStudio.convert(min_temp, 'F', 'C').get
      end
    end

    # create new rules and add to default day based on flex period options above
    idx = 0
    flex_times.each do |ft|
      d_day.addValue(ft, new_values[idx])
      idx += 1
    end

    ## END CONTROLS: HEAT PUMP HEATING TEMPERATURE SETPOINT SCHEDULE ---------------------------------------------------

    ## CONTROLS: TANK TEMPERATURE SETPOINT SCHEDULE (ELECTRIC BACKUP) --------------------------------------------------
    # This section creates the setpoint temperature schedule for the electric backup heating coils in the water tank

    # grab default day and time-value pairs for modification
    d_day = tank_sched.defaultDaySchedule
    old_times = d_day.times
    old_values = d_day.values
    new_values = Array.new(flex_times.size, 2)

    # find existing values in reference schedule and grab for use in new-rule creation
    flex_times.size.times do |i|
      if i.even?
        n = 0
        old_times.each do |ot|
          new_values[i] = old_values[n] if flex_times[i] <= ot
          n += 1
        end
      elsif flex_type[(i / 2).floor] == 'Charge - Electric'
        new_values[i] = OpenStudio.convert(max_temp, 'F', 'C').get
      elsif flex_type[(i / 2).floor] == 'Float' # || flex_type[(i/2).floor] == 'Charge - Heat Pump'
        new_values[i] = OpenStudio.convert(min_temp - db_temp, 'F', 'C').get
      elsif flex_type[(i / 2).floor] == 'Charge - Heat Pump'
        new_values[i] = 60 - (db_temp / 1.8)
      end
    end

    # create new rules and add to default day based on flex period options above
    idx = 0
    flex_times.each do |ft|
      d_day.addValue(ft, new_values[idx])
      idx += 1
    end

    ## CONTROLS: TANK TEMPERATURE SETPOINT SCHEDULE (ELECTRIC BACKUP) --------------------------------------------------

    ## HARDWARE --------------------------------------------------------------------------------------------------------
    # This section adds the selected type of heat pump water heater to the supply side of the selected loop. If
    # selected, measure will remove any existing water heaters on the supply side of the loop. If old heater(s) are left
    # in place, the new HPWH tank will be placed in front (to the left) of them.

    # use OS standards build - arbitrary selection, but NZE Ready seems appropriate
    std = Standard.build('NREL ZNE Ready 2017')

    # create empty arrays and initialize variables for later use
    old_heater = []
    count = 0

    # convert loop and zone names from STRINGS into OS model OBJECTS
    zone =  model.getThermalZoneByName(zone).get
    loop =  model.getPlantLoopByName(loop).get

    # find and locate old water heater on selected loop, if applicable
    loop_equip = loop.supplyComponents
    loop_equip.each do |le|
      if le.iddObject.name.include?('WaterHeater:Mixed')
        old_heater << model.getWaterHeaterMixedByName(le.name.to_s).get
        count += 1
      elsif le.iddObject.name.include?('WaterHeater:Stratified')
        old_heater << model.getWaterHeaterStratifiedByName(le.name.to_s).get
        count += 1
      end
    end

    unless old_heater.empty?
      inlet = old_heater[0].supplyInletModelObject.get.to_Node.get
      outlet = old_heater[0].supplyOutletModelObject.get.to_Node.get
    end

    # Add heat pump water heater and attach to selected loop
    # Reference: https://github.com/NREL/openstudio-standards/blob/master/lib/
    # => openstudio-standards/prototypes/common/objects/Prototype.ServiceWaterHeating.rb
    if type != 'Simplified'
      hpwh = std.model_add_heatpump_water_heater(model, # model
                                                 type: type,                                                           # type
                                                 water_heater_capacity: (cap * 1000 / cop),                            # water_heater_capacity
                                                 electric_backup_capacity: (bu_cap * 1000),                            # electric_backup_capacity
                                                 water_heater_volume: OpenStudio.convert(vol, 'gal', 'm^3').get,       # water_heater_volume
                                                 service_water_temperature: OpenStudio.convert(140.0, 'F', 'C').get,   # service_water_temperature
                                                 parasitic_fuel_consumption_rate: 3.0,                                 # parasitic_fuel_consumption_rate
                                                 swh_temp_sch: sched,                                                  # swh_temp_sch
                                                 cop: cop,                                                             # cop
                                                 shr: 0.88,                                                            # shr
                                                 tank_ua: 3.9,                                                         # tank_ua
                                                 set_peak_use_flowrate: false,                                         # set_peak_use_flowrate
                                                 peak_flowrate: 0.0,                                                   # peak_flowrate
                                                 flowrate_schedule: nil,                                               # flowrate_schedule
                                                 water_heater_thermal_zone: zone)                                      # water_heater_thermal_zone
    else
      hpwh = std.model_add_water_heater(model, # model
                                        (cap * 1000),                                                         # water_heater_capacity
                                        OpenStudio.convert(vol, 'gal', 'm^3').get,                            # water_heater_volume
                                        'HeatPump',                                                           # water_heater_fuel
                                        OpenStudio.convert(140.0, 'F', 'C').get,                              # service_water_temperature
                                        3.0,                                                                  # parasitic_fuel_consumption_rate
                                        sched,                                                                # swh_temp_sch
                                        false,                                                                # set_peak_use_flowrate
                                        0.0,                                                                  # peak_flowrate
                                        nil,                                                                  # flowrate_schedule
                                        zone,                                                                 # water_heater_thermal_zone
                                        1)                                                                    # number_water_heaters
    end

    # add tank to appropriate branch and node (will be placed first in series if old tanks not removed)
    # modify objects as ncessary
    if old_heater.empty?
      loop.addSupplyBranchForComponent(hpwh.tank)
    elsif type != 'Simplified'
      hpwh.tank.addToNode(inlet)
      hpwh.setDeadBandTemperatureDifference(db_temp / 1.8)
      runner.registerInfo("#{hpwh.tank.name} was added to the model on #{loop.name}")
    else
      hpwh.addToNode(inlet)
      hpwh.setMaximumTemperatureLimit(OpenStudio.convert(max_temp, 'F', 'C').get)
      runner.registerInfo("#{hpwh.name} was added to the model on #{loop.name}")
    end

    # remove old tank objects if necessary
    if remove_wh
      old_heater.each do |oh|
        runner.registerInfo("#{oh.name} was removed from the model.")
        oh.remove
      end
    end
    ## END HARDWARE ----------------------------------------------------------------------------------------------------

    ## CONTROLS MODIFICATIONS FOR TANK ---------------------------------------------------------------------------------
    # apply schedule to tank
    if type == 'PumpedCondenser'
      hpwh.tank.to_WaterHeaterMixed.get.setSetpointTemperatureSchedule(tank_sched)
    elsif type == 'WrappedCondenser'
      hpwh.tank.to_WaterHeaterStratified.get.setHeater1SetpointTemperatureSchedule(tank_sched)
      hpwh.tank.to_WaterHeaterStratified.get.setHeater2SetpointTemperatureSchedule(tank_sched)
    elsif type == 'Simplified'
      runner.registerInfo('Line 492 was used. Nothing done here yet... Check tank temperature schedules...')
    end
    ## END CONTROLS MODIFICATIONS FOR TANK -----------------------------------------------------------------------------

    ## ADD REPORTED VARIABLES ------------------------------------------------------------------------------------------

    ovar_names = ['Cooling Coil Total Cooling Rate',
                  'Cooling Coil Total Water Heating Rate',
                  'Cooling Coil Water Heating Electric Power',
                  'Cooling Coil Crankcase Heater Electric Power',
                  'Water Heater Tank Temperature',
                  'Water Heater Heat Loss Rate',
                  'Water Heater Heating Rate',
                  'Water Heater Use Side Heat Transfer Rate',
                  'Water Heater Source Side Heat Transfer Rate',
                  'Water Heater Unmet Demand Heat Transfer Rate',
                  'Water Heater Electric Power',
                  'Water Heater Water Volume Flow Rate',
                  'Water Use Connections Hot Water Temperature']

    # Create new output variable objects
    ovars = []
    ovar_names.each do |nm|
      ovars << OpenStudio::Model::OutputVariable.new(nm, model)
    end

    # add temperate schedule outputs - clean up and put names into array, then loop over setting key values
    v = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    v.setKeyValue(sched.name.to_s)
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    v.setKeyValue(tank_sched.name.to_s)
    ovars << v

    if type != 'Simplified'
      v = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
      v.setKeyValue(tank_sched.name.to_s)
      ovars << v
    end

    # Set variable reporting frequency for newly created output variables
    ovars.each do |var|
      var.setReportingFrequency('TimeStep')
    end

    # Register info re: output variables:
    runner.registerInfo("#{ovars.size} output variables were added to the model.")
    ## END ADD REPORTED VARIABLES --------------------------------------------------------------------------------------

    # Register final condition
    hpwh_fc = model.getWaterHeaterHeatPumps.size + model.getWaterHeaterHeatPumpWrappedCondensers.size
    tanks_fc = model.getWaterHeaterMixeds.size + model.getWaterHeaterStratifieds.size
    runner.registerFinalCondition("The building finshed with #{tanks_fc} water heater tank(s) and " \
                                  "#{hpwh_fc} heat pump water heater(s).")

    true
  end
end

# register the measure to be used by the application
AddCentralHPWHForLoadFlexibility.new.registerWithApplication
