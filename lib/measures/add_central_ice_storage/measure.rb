# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
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
# Date: June 2019 - July 2020
# Additional Code Added to Test Ice Performance for Demand Response Events: September 2019
# Revised February 2020

# References:
# => ASHRAE Handbook, HVAC Systems and Equipment, Chapter 51: Thermal storage, 2016
# => ASHRAE Design Guide for Cool Thermal Storage, 2nd Edition, January 2019
# => Manufacturer marketing materials, available online

# load OpenStudio measure libraries
require "#{File.dirname(__FILE__)}/resources/OsLib_Schedules"

# start the measure
class AddCentralIceStorage < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    'Add Central Ice Storage'
  end

  # human readable description
  def description
    'This measure adds an ice storage tank to a chilled water loop for the purpose of thermal energy storage.'
  end

  # human readable description of modeling approach
  def modeler_description
    'This measure adds the necessary components and performs required model articulations to add an ice ' \
            'thermal storage tank (ITS) to an existing chilled water loop. Special consideration is given to ' \
            'implementing configuration and control options. Refer to the ASHRAE CTES Design Guide or manufacturer ' \
            'applications guides for detailed implementation info. A user guide document is included in the docs ' \
            'folder of this measure to help translate design objectives into measure argument input values.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Make choice argument for energy storage objective
    objective = OpenStudio::Measure::OSArgument.makeChoiceArgument('objective', ['Full Storage', 'Partial Storage'], true)
    objective.setDisplayName('Select Energy Storage Objective:')
    objective.setDefaultValue('Partial Storage')
    args << objective

    # Make choice argument for component layout
    upstream = OpenStudio::Measure::OSArgument.makeChoiceArgument('upstream', ['Chiller', 'Storage'])
    upstream.setDisplayName('Select Upstream Device:')
    upstream.setDescription('Partial Storage Only. See documentation for control implementation.')
    upstream.setDefaultValue('Chiller')
    args << upstream

    # Make double argument for thermal energy storage capacity
    storage_capacity = OpenStudio::Measure::OSArgument.makeDoubleArgument('storage_capacity', true)
    storage_capacity.setDisplayName('Enter Thermal Energy Storage Capacity for Ice Tank [ton-hours]:')
    storage_capacity.setDefaultValue(2000)
    args << storage_capacity

    # Make choice argument for ice melt process indicator
    melt_indicator = OpenStudio::Measure::OSArgument.makeChoiceArgument('melt_indicator', ['InsideMelt', 'OutsideMelt'], true)
    melt_indicator.setDisplayName('Select Thaw Process Indicator for Ice Storage:')
    melt_indicator.setDescription('')
    melt_indicator.setDefaultValue('InsideMelt')
    args << melt_indicator

    # Make list of chilled water loop(s) from which user can select
    plant_loops = model.getPlantLoops
    loop_choices = OpenStudio::StringVector.new
    plant_loops.each do |loop|
      if loop.sizingPlant.loopType.to_s == 'Cooling'
        loop_choices << loop.name.to_s
      end
    end

    # Make choice argument for loop selection
    selected_loop = OpenStudio::Measure::OSArgument.makeChoiceArgument('selected_loop', loop_choices, true)
    selected_loop.setDisplayName('Select Loop:')
    selected_loop.setDescription('This is the cooling loop on which the ice tank will be added.')
    if loop_choices.include?('Chilled Water Loop')
      selected_loop.setDefaultValue('Chilled Water Loop')
    else
      selected_loop.setDescription('Error: No Cooling Loop Found')
    end
    args << selected_loop

    # Make list of available chillers from which the user can select
    chillers = model.getChillerElectricEIRs
    chillers += model.getChillerAbsorptions
    chillers += model.getChillerAbsorptionIndirects
    chiller_choices = OpenStudio::StringVector.new
    chillers.each do |chill|
      chiller_choices << chill.name.to_s
    end

    # Make choice argument for chiller selection
    selected_chiller = OpenStudio::Measure::OSArgument.makeChoiceArgument('selected_chiller', chiller_choices, true)
    selected_chiller.setDisplayName('Select Chiller:')
    selected_chiller.setDescription('The ice tank will be placed in series with this chiller.')
    if !chillers.empty?
      selected_chiller.setDefaultValue(chiller_choices[0])
    else
      selected_chiller.setDescription('Error: No Chiller Found')
    end
    args << selected_chiller

    # Make double argument for ice chiller resizing factor - relative to selected chiller capacity
    chiller_resize_factor = OpenStudio::Measure::OSArgument.makeDoubleArgument('chiller_resize_factor', false)
    chiller_resize_factor.setDisplayName('Enter Chiller Sizing Factor:')
    chiller_resize_factor.setDefaultValue(0.75)
    args << chiller_resize_factor

    # Make double argument for chiller max capacity limit during ice discharge
    chiller_limit = OpenStudio::Measure::OSArgument.makeDoubleArgument('chiller_limit', false)
    chiller_limit.setDisplayName('Enter Chiller Max Capacity Limit During Ice Discharge:')
    chiller_limit.setDescription('Enter as a fraction of chiller capacity (0.0 - 1.0).')
    chiller_limit.setDefaultValue(1.0)
    args << chiller_limit

    # Make choice argument for schedule options
    old = OpenStudio::Measure::OSArgument.makeBoolArgument('old', false)
    old.setDisplayName('Use Existing (Pre-Defined) Temperature Control Schedules')
    old.setDescription('Use drop-down selections below.')
    old.setDefaultValue(false)
    args << old

    # Find All Existing Schedules with Type Limits of "Temperature"
    sched_options = []
    sched_options2 = []
    all_scheds = model.getSchedules
    all_scheds.each do |sched|
      sched.to_ScheduleBase.get
      unless sched.scheduleTypeLimits.empty?
        case sched.scheduleTypeLimits.get.unitType.to_s
        when 'Temperature'
          sched_options << sched.name.to_s
        when 'Availability', 'OnOff'
          sched_options2 << sched.name.to_s
        end
      end
    end
    sched_options = ['N/A'] + sched_options.sort
    sched_options2 = ['N/A'] + sched_options2.sort

    # Create choice argument for ice availability schedule (old = true)
    ctes_av = OpenStudio::Measure::OSArgument.makeChoiceArgument('ctes_av', sched_options2, false)
    ctes_av.setDisplayName('Select Pre-Defined Ice Availability Schedule')
    if sched_options2.empty?
      ctes_av.setDescription('Warning: No availability schedules found')
    end
    ctes_av.setDefaultValue('N/A')
    args << ctes_av

    # Create choice argument for ice tank component setpoint sched (old = true)
    ctes_sch = OpenStudio::Measure::OSArgument.makeChoiceArgument('ctes_sch', sched_options, false)
    ctes_sch.setDisplayName('Select Pre-Defined Ice Tank Component Setpoint Schedule')
    if sched_options.empty?
      ctes_sch.setDescription('Warning: No temperature setpoint schedules found')
    end
    ctes_sch.setDefaultValue('N/A')
    args << ctes_sch

    # Create choice argument for chiller component setpoint sched (old = true)
    chill_sch = OpenStudio::Measure::OSArgument.makeChoiceArgument('chill_sch', sched_options, false)
    chill_sch.setDisplayName('Select Pre-Defined Chiller Component Setpoint Schedule')
    if sched_options.empty?
      chill_sch.setDescription('Warning: No temperature setpoint schedules found')
    end
    chill_sch.setDefaultValue('N/A')
    args << chill_sch

    # Make bool argument for creating new schedules
    new = OpenStudio::Measure::OSArgument.makeBoolArgument('new', false)
    new.setDisplayName('Create New (Simple) Temperature Control Schedules')
    new.setDescription('Use entry fields below. If Pre-Defined is also selected, these new schedules will be created' \
                       ' but not applied.')
    new.setDefaultValue(true)
    args << new

    # Make double argument for loop setpoint temperature
    loop_sp = OpenStudio::Measure::OSArgument.makeDoubleArgument('loop_sp', true)
    loop_sp.setDisplayName('Loop Setpoint Temperature F:')
    loop_sp.setDescription('This value replaces the existing loop temperature setpoint manager; the old manager will ' \
                           'be disconnected but not deleted from the model.')
    loop_sp.setDefaultValue(44)
    args << loop_sp

    # Make double argument for ice chiller outlet temp during partial storage operation
    inter_sp = OpenStudio::Measure::OSArgument.makeDoubleArgument('inter_sp', false)
    inter_sp.setDisplayName('Enter Intermediate Setpoint for Upstream Cooling Device During Ice Discharge F:')
    inter_sp.setDescription('Partial storage only')
    inter_sp.setDefaultValue(47)
    args << inter_sp

    # Make double argument for loop temperature for ice charging
    chg_sp = OpenStudio::Measure::OSArgument.makeDoubleArgument('chg_sp', true)
    chg_sp.setDisplayName('Ice Charging Setpoint Temperature F:')
    chg_sp.setDefaultValue(25)
    args << chg_sp

    # Make double argument for loop design delta T
    delta_t = OpenStudio::Measure::OSArgument.makeStringArgument('delta_t', true)
    delta_t.setDisplayName('Loop Design Temperature Difference F:')
    delta_t.setDescription('Enter numeric value to adjust selected loop settings.')
    delta_t.setDefaultValue('Use Existing Loop Value')
    args << delta_t

    # Make string argument for ctes seasonal availabilty
    ctes_season = OpenStudio::Measure::OSArgument.makeStringArgument('ctes_season', true)
    ctes_season.setDisplayName('Enter Seasonal Availabity of Ice Storage:')
    ctes_season.setDescription('Use MM/DD-MM/DD format')
    ctes_season.setDefaultValue('01/01-12/31')
    args << ctes_season

    # Make string arguments for ctes discharge times
    discharge_start = OpenStudio::Measure::OSArgument.makeStringArgument('discharge_start', true)
    discharge_start.setDisplayName('Enter Starting Time for Ice Discharge:')
    discharge_start.setDescription('Use 24 hour format (HR:MM)')
    discharge_start.setDefaultValue('08:00')
    args << discharge_start

    discharge_end = OpenStudio::Measure::OSArgument.makeStringArgument('discharge_end', true)
    discharge_end.setDisplayName('Enter End Time for Ice Discharge:')
    discharge_end.setDescription('Use 24 hour format (HR:MM)')
    discharge_end.setDefaultValue('21:00')
    args << discharge_end

    # Make string arguments for ctes charge times
    charge_start = OpenStudio::Measure::OSArgument.makeStringArgument('charge_start', true)
    charge_start.setDisplayName('Enter Starting Time for Ice charge:')
    charge_start.setDescription('Use 24 hour format (HR:MM)')
    charge_start.setDefaultValue('23:00')
    args << charge_start

    charge_end = OpenStudio::Measure::OSArgument.makeStringArgument('charge_end', true)
    charge_end.setDisplayName('Enter End Time for Ice charge:')
    charge_end.setDescription('Use 24 hour format (HR:MM)')
    charge_end.setDefaultValue('07:00')
    args << charge_end

    # Make boolean arguments for ctes dischage days
    wknds = OpenStudio::Measure::OSArgument.makeBoolArgument('wknds', true)
    wknds.setDisplayName('Allow Ice Discharge on Weekends')
    wknds.setDefaultValue(false)
    args << wknds

    # Make choice argument for output variable reporting frequency
    report_choices = ['Detailed', 'Timestep', 'Hourly', 'Daily', 'Monthly', 'RunPeriod']
    report_freq = OpenStudio::Measure::OSArgument.makeChoiceArgument('report_freq', report_choices, false)
    report_freq.setDisplayName('Select Reporting Frequency for New Output Variables')
    report_freq.setDescription('This will not change reporting frequency for existing output variables in the model.')
    report_freq.setDefaultValue('Timestep')
    args << report_freq

    ## DR TESTER INPUTS -----------------------------------------
    # Make boolean argument for use of demand response event test
    dr = OpenStudio::Measure::OSArgument.makeBoolArgument('dr', false)
    dr.setDisplayName('Test Demand Reponse Event')
    dr.setDefaultValue(false)
    args << dr

    # Make choice argument for type of demand response event (add or shed)
    dr_add_shed = OpenStudio::Measure::OSArgument.makeChoiceArgument('dr_add_shed', ['Add', 'Shed'], false)
    dr_add_shed.setDisplayName('Select if a Load Add or Load Shed Event')
    dr_add_shed.setDefaultValue('Shed')
    args << dr_add_shed

    # Make string argument for DR event date
    dr_date = OpenStudio::Measure::OSArgument.makeStringArgument('dr_date', false)
    dr_date.setDisplayName('Enter date of demand response event:')
    dr_date.setDescription('Use MM/DD format.')
    dr_date.setDefaultValue('9/19')
    args << dr_date

    # Make string argument for DR Event time
    dr_time = OpenStudio::Measure::OSArgument.makeStringArgument('dr_time', false)
    dr_time.setDisplayName('Enter start time of demand response event:')
    dr_time.setDescription('Use 24 hour format (HR:MM)')
    dr_time.setDefaultValue('11:30')
    args << dr_time

    # Make double argument for DR event duration
    dr_dur = OpenStudio::Measure::OSArgument.makeDoubleArgument('dr_dur', false)
    dr_dur.setDisplayName('Enter duration of demand response event [hr]:')
    dr_dur.setDefaultValue(3)
    args << dr_dur

    # Make boolean argument for allowing chiller to back-up ice
    dr_chill = OpenStudio::Measure::OSArgument.makeBoolArgument('dr_chill', false)
    dr_chill.setDisplayName('Allow chiller to back-up ice during DR event')
    dr_chill.setDescription('Unselection may result in unmet cooling hours')
    dr_chill.setDefaultValue('false')
    args << dr_chill
    ## END DR TESTER INPUTS --------------------------------------

    args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    ## Arguments and Declarations---------------------------------------------------------------------------------------
    # Assign user arguments to variables
    objective = runner.getStringArgumentValue('objective', user_arguments)
    upstream = runner.getStringArgumentValue('upstream', user_arguments)
    storage_capacity = runner.getDoubleArgumentValue('storage_capacity', user_arguments)
    melt_indicator = runner.getStringArgumentValue('melt_indicator', user_arguments)
    selected_loop = runner.getStringArgumentValue('selected_loop', user_arguments)
    selected_chiller = runner.getStringArgumentValue('selected_chiller', user_arguments)
    chiller_resize_factor = runner.getDoubleArgumentValue('chiller_resize_factor', user_arguments)
    chiller_limit = runner.getDoubleArgumentValue('chiller_limit', user_arguments)
    old = runner.getBoolArgumentValue('old', user_arguments)
    ctes_av = runner.getStringArgumentValue('ctes_av', user_arguments)
    ctes_sch = runner.getStringArgumentValue('ctes_sch', user_arguments)
    chill_sch = runner.getStringArgumentValue('chill_sch', user_arguments)
    new = runner.getBoolArgumentValue('new', user_arguments)
    loop_sp = runner.getDoubleArgumentValue('loop_sp', user_arguments)
    inter_sp = runner.getDoubleArgumentValue('inter_sp', user_arguments)
    chg_sp = runner.getDoubleArgumentValue('chg_sp', user_arguments)
    delta_t = runner.getStringArgumentValue('delta_t', user_arguments)
    ctes_season = runner.getStringArgumentValue('ctes_season', user_arguments)
    discharge_start = runner.getStringArgumentValue('discharge_start', user_arguments)
    discharge_end = runner.getStringArgumentValue('discharge_end', user_arguments)
    charge_start = runner.getStringArgumentValue('charge_start', user_arguments)
    charge_end = runner.getStringArgumentValue('charge_end', user_arguments)
    wknds = runner.getBoolArgumentValue('wknds', user_arguments)
    report_freq = runner.getStringArgumentValue('report_freq', user_arguments)

    ## DR TESTER INPUTS ----------------------------------
    dr = runner.getBoolArgumentValue('dr', user_arguments)
    dr_add_shed = runner.getStringArgumentValue('dr_add_shed', user_arguments)
    (dr_mon, dr_day) = runner.getStringArgumentValue('dr_date', user_arguments).split('/')
    (dr_hr, dr_min) = runner.getStringArgumentValue('dr_time', user_arguments).split(':')
    dr_dur = runner.getDoubleArgumentValue('dr_dur', user_arguments)
    dr_chill = runner.getBoolArgumentValue('dr_chill', user_arguments)
    dr_time = (dr_hr.to_f + (dr_min.to_f / 60)).round(2)
    ## END DR TESTER INPUTS ------------------------------

    # Declare useful variables with values set within do-loops
    cond_loop = ''
    ctes_sp_sched = ''
    ctes_setpoint = 99.0 # This is a flag value and should be overwritten later
    demand_sp_mgr = ''

    ## Validate User Inputs---------------------------------------------------------------------------------------------

    # Convert thermal storage capacity from ton-hours to GJ
    storage_capacity = 0.0126606708 * storage_capacity

    # Check for existence of charging setpoint temperature, reset to default if left blank.
    if chg_sp.nil? || chg_sp >= 32.0
      runner.registerWarning('An invalid ice charging temperature was entered. Value reset to -3.88 C (25.0 F).')
      chg_sp = 25.0
    elsif chg_sp < 20.0
      runner.registerWarning('The ice charging temperature is set below 20 F; this is atypically low. Verify input.')
    end

    # Convert setpoint temperature inputs from F to C
    loop_sp = (loop_sp - 32.0) / 1.8
    inter_sp = (inter_sp - 32.0) / 1.8
    chg_sp = (chg_sp - 32.0) / 1.8

    # Check if both old and new are false, set new = true and report error
    if !old && !new
      runner.registerError('No CTES schedule option was selected; either use old schedules or the create new option. ' \
                           'Measure aborted.')
      return false
    end

    # Locate selected chiller and verify loop connection
    if !model.getChillerElectricEIRByName(selected_chiller).empty?
      ctes_chiller = model.getChillerElectricEIRByName(selected_chiller).get
    elsif !model.getChillerAbsorptionByName(selected_chiller).empty?
      ctes_chiller = model.getChillerAbsorptionByName(selected_chiller).get
    elsif !model.getChillerAbsorptionIndirectByName(selected_chiller).empty?
      ctes_chiller = model.getChillerAbsorptionIndirectByName(selected_chiller).get
    end

    ctes_loop = model.getModelObjectByName(selected_loop).get.to_PlantLoop.get

    unless ctes_loop.components.include?(ctes_chiller)
      runner.registerError('The selected chiller is not located on the selected chilled water loop. Measure aborted.')
      return false
    end

    # Convert Delta T if needed from F to C (Overwrites string variables as floats)
    if delta_t != 'Use Existing Loop Value' && delta_t.to_f > 0.0
      delta_t = delta_t.to_f / 1.8
    else
      # Could add additional checks here for invalid (non-numerical) entries
      delta_t = ctes_loop.sizingPlant.loopDesignTemperatureDifference
    end

    # Check chiller limit input values
    if chiller_limit > 1.0
      runner.registerWarning('Chiller limit must be a ratio less than 1. Limit set to 1.0.')
      chiller_limit = 1.0
    elsif chiller_limit < 0
      runner.registerWarning('Chiller limit must be a ratio greater than or equal to 0. Limit set to 0.0' \
                              ' (i.e. full storage).')
      chiller_limit = 0.0
    elsif chiller_limit < 0.15
      runner.registerInfo('Chiller limit is below 15%; this may be outside the reasonable part load operating " \
                          "window for the device. Consider increasing or setting to 0.')
    end

    # Convert chiller limit to a temperature value based on delta_t variable if != 1. Otherwise, use as flag for EMS
    if chiller_limit < 1.0
      dt_max = chiller_limit * delta_t # degrees C
      runner.registerInfo("Max chiller dT during ice discharge is set to: #{dt_max.round(2)} C " \
                          "(#{(dt_max * 1.8).round(2)} F).")
    else
      dt_max = delta_t
    end

    # Check limits of chiller performance curves and adjust if necessary - Notify user with WARNING
    curve_output_check = false
    cap_ft = ctes_chiller.coolingCapacityFunctionOfTemperature.to_CurveBiquadratic.get
    min_x = cap_ft.minimumValueofx.to_f
    if min_x > chg_sp
      cap_ft.setMinimumValueofx(chg_sp)
      runner.registerWarning("VERIFY CURVE VALIDITY: The input range for the '#{cap_ft.name}' curve is too " \
                            'restrictive for use with ice charging. The provided curve has been ' \
                            "extrapolated to a lower limit of #{chg_sp.round(2)} C for the 'x' variable.")
      curve_output_check = true
    end

    eir_ft = ctes_chiller.electricInputToCoolingOutputRatioFunctionOfTemperature.to_CurveBiquadratic.get
    min_x = eir_ft.minimumValueofx.to_f
    if min_x > chg_sp
      runner.registerWarning("VERIFY CURVE VALIDITY: The input range for the '#{eir_ft.name}' curve is too " \
                            'restrictive for use with ice charging. The provided curve has been ' \
                            "extrapolated to a lower limit of #{chg_sp.round(2)} C for the 'x' variable.")
    end

    # Report chiller performance derate at the ice-making conditions.
    if curve_output_check == true
      derate = cap_ft.evaluate(chg_sp, ctes_chiller.referenceEnteringCondenserFluidTemperature)
      runner.registerInfo('A curve extrapolation warning was registered for the chiller capacity as a function ' \
                          'of temperature curve. At normal ice making temperatures, a chiller derate to 60-70% ' \
                          'of nominal capacity is expected. Using a condenser entering water temperature of ' \
                          "#{ctes_chiller.referenceEnteringCondenserFluidTemperature.round(1)} C and the ice " \
                          "charging temperature of #{chg_sp.round(1)} C, a derate to #{(derate * 100).round(1)}% is " \
                          'returned. This value will increase with lower condenser fluid return temperatures.')
    end

    # Check to ensure schedules are selected if old = true
    if old
      if ctes_av == 'N/A'
        runner.registerError('Pre-Defined schedule option chosen, but no availabity schedule was selected.')
        runner.registerWarning('Measure terminated early; no storage was applied.')
        return false
      end
      if ctes_sch == 'N/A'
        runner.registerError('Pre-Defined schedule option chosen, but no ice tank setpoint schedule was selected.')
        runner.registerWarning('Measure terminated early; no storage was applied.')
        return false
      end
      if chill_sch == 'N/A'
        runner.registerError('Pre-Defined schedule option chosen, but no chiller setpoint schedule was selected.')
        runner.registerWarning('Measure terminated early; no storage was applied.')
        return false
      end
    end

    # Parse and verify schedule inputs
    # Remove potential spaces from date inputs
    ctes_season = ctes_season.delete(' ')

    # Convert HR:MM format into HR.fraction format
    (d_start_hr, d_start_min) = discharge_start.split(':')
    (d_end_hr, d_end_min) = discharge_end.split(':')
    (c_start_hr, c_start_min) = charge_start.split(':')
    (c_end_hr, c_end_min) = charge_end.split(':')

    # Store re-formatted time values in shorthand variables for use in schedule
    # building
    ds = (d_start_hr.to_f + d_start_min.to_f / 60).round(2)
    de = (d_end_hr.to_f + d_end_min.to_f / 60).round(2)
    cs = (c_start_hr.to_f + c_start_min.to_f / 60).round(2)
    ce = (c_end_hr.to_f + c_end_min.to_f / 60).round(2)

    # Verify that input times make sense
    if ds > de
      runner.registerWarning('Dischage start time is later than discharge ' \
                             'end time (your ice will discharge overnight). ' \
                             'Verify schedule inputs.')
    end

    if cs.between?(ds - 0.01, de + 0.01) || ce.between?(ds - 0.01, de + 0.01)
      runner.registerWarning('The tank charge and discharge periods overlap. ' \
                             'Examine results for unexpected operation; ' \
                             'verify schedule inputs.')
    end

    if [ds, de, cs, ce].any? { |i| i > 24 }
      runner.registerError('One of you time enteries exceeds 24:00, ' \
                           'resulting in a schedule error. Measure aborted.')
      return false
    end

    ## Report Initial Condition of the Model----------------------------------------------------------------------------
    total_storage = model.getThermalStorageIceDetaileds.size
    runner.registerInitialCondition("The model started with #{total_storage} ice storage device(s).")

    runner.registerInfo("Chiller '#{selected_chiller}' on Loop '#{selected_loop}' was selected for the addition " \
                        "of a #{storage_capacity.round(2)} GJ (#{(storage_capacity / 0.0126606708).round(0)} " \
                        'ton-hours) ice thermal energy storage object.')

    ## Modify Chiller Settings------------------------------------------------------------------------------------------

    # Adjust ctes chiller minimum outlet temperature
    ctes_chiller.setLeavingChilledWaterLowerTemperatureLimit(chg_sp)
    runner.registerInfo("Selected chiller minimum setpoint temperature was adjusted to #{chg_sp.round(2)} C " \
                        "(#{(chg_sp * 1.8) + 32} F).")

    # Adjust ctes chiller sizing factor based on user input
    if ctes_chiller.isReferenceCapacityAutosized
      ctes_chiller.setSizingFactor(chiller_resize_factor)
      runner.registerInfo("Selected chiller has been resized to #{chiller_resize_factor * 100}% of autosized " \
                          'capacity.')
    else
      ctes_chiller.setReferenceCapacity(
        chiller_resize_factor * ctes_chiller.referenceCapacity.to_f
      )
      runner.registerInfo("Selected chiller has been resized to #{chiller_resize_factor * 100}% of original " \
                          '(hardsized) capacity.')
    end

    ## Modify Loop Settings---------------------------------------------------------------------------------------------

    # Adjust minimum loop temperature
    ctes_loop.setMinimumLoopTemperature(chg_sp)
    runner.registerInfo("Selected loop minimum temperature was adjusted to #{chg_sp.round(2)} C " \
                        "(#{(chg_sp * 1.8) + 32} F).")

    # Adjust plant load distribution scheme
    if ctes_loop.loadDistributionScheme != 'SequentialLoad'
      ctes_loop.setLoadDistributionScheme('SequentialLoad')
      runner.registerInfo("Selected loop load distribution scheme was set to 'SequentialLoad'.")
    end

    # Adjust loop design temperature difference
    ctes_loop.sizingPlant.setLoopDesignTemperatureDifference(delta_t)
    runner.registerInfo("Selected loop design temperature difference was set to #{delta_t.round(2)} C " \
                        "(#{delta_t * 1.8} F).")

    # Adjust loop gylcol solution percentage and set glycol - if necessary
    if ctes_loop.fluidType == 'Water'
      ctes_loop.setFluidType('EthyleneGlycol')
      ctes_loop.setGlycolConcentration(25)
      runner.registerInfo('Selected loop working fluid changed to ethylene glycol at a 25% concentration.')
    elsif ctes_loop.glycolConcentration < 25
      runner.registerInfo('Selected loop gylycol concentration is less than 25%. Consider increasing to 25-30%.')
    end

    # Adjust loop to two-way common pipe simulation - if necessary
    if ctes_loop.commonPipeSimulation != 'TwoWayCommonPipe'
      ctes_loop.setCommonPipeSimulation('TwoWayCommonPipe')
      runner.registerInfo("Selected loop common pipe simulation changed to 'TwoWayCommonPipe'.")

      # Add setpoint manager at inlet of demand loop (req'd for two-way common pipe sim.)
      if old # Only applies if old curves are used, regardless of whether new curves are created (old takes precedence)
        loop_sp_node = ctes_loop.loopTemperatureSetpointNode
        loop_sp_mgrs = loop_sp_node.setpointManagers
        loop_sp_mgrs.each do |spm|
          if spm.controlVariable == 'Temperature'
            demand_sp_mgr = spm.clone.to_SetpointManagerScheduled.get
          end
        end
        demand_sp_mgr.addToNode(ctes_loop.demandInletNode)
        runner.registerInfo('Original loop temperature setpoint manager duplicated and added to demand loop inlet node.')
      end

    end

    ## Create CTES Hardware---------------------------------------------------------------------------------------------

    # Create ice tank (aka ctes)
    ctes = OpenStudio::Model::ThermalStorageIceDetailed.new(model)
    ctes.setCapacity(storage_capacity)
    ctes.setThawProcessIndicator(melt_indicator)

    # Add ice tank to loop based on user-selected objective option and upstream device
    if objective == 'Full Storage'
      # Full storage places the ice tank upstream of the chiller with no user option to change.
      ctes.addToNode(ctes_chiller.supplyInletModelObject.get.to_Node.get)
    elsif objective == 'Partial Storage' && upstream == 'Storage'
      ctes.addToNode(ctes_chiller.supplyInletModelObject.get.to_Node.get)
    elsif objective == 'Partial Storage' && upstream == 'Chiller'
      ctes.addToNode(ctes_chiller.supplyOutletModelObject.get.to_Node.get)
    end

    ## Create New Schedules if Necessary--------------------------------------------------------------------------------
    #-------------------------------------------------------------------------------------------------------------------
    if new
      ## Check for Schedule Type Limits and Create if Needed------------------------------------------------------------
      if model.getModelObjectByName('OnOff').get.initialized
        sched_limits_onoff = model.getModelObjectByName('OnOff').get.to_ScheduleTypeLimits.get
      else
        sched_limits_onoff = OpenStudio::Model::ScheduleTypeLimits.new(model)
        sched_limits_onoff.setName('OnOff')
        sched_limits_onoff.setNumericType('Discrete')
        sched_limits_onoff.setUnitType('Availability')
        sched_limits_onoff.setLowerLimitValue(0.0)
        sched_limits_onoff.setUpperLimitValue(1.0)
      end

      if model.getModelObjectByName('Temperature').get.initialized
        sched_limits_temp = model.getModelObjectByName('Temperature').get.to_ScheduleTypeLimits.get
        if sched_limits_temp.lowerLimitValue.to_f > chg_sp
          sched_limits_temp.setLowerLimitValue(chg_sp)
        end
      else
        sched_limits_temp = OpenStudio::Model::ScheduleTypeLimits.new(model)
        sched_limits_temp.setName('Temperature')
        sched_limits_temp.setNumericType('Continuous')
        sched_limits_temp.setUnitType('Temperature')
      end

      ## Create Schedules-----------------------------------------------------------------------------------------------

      # Create key-value sets based on user inputs for charge/discharge times
      # cs = charge start, ce = charge end, ds = discharge start, de = discharge end

      # Set chiller and ice discharge setpoints for partial storage configs
      case objective
      when 'Full Storage'
        chiller_setpoint = loop_sp
        ctes_setpoint = loop_sp
      when 'Partial Storage'
        case upstream
        when 'Chiller'
          chiller_setpoint = inter_sp
          ctes_setpoint = loop_sp
        when 'Storage'
          chiller_setpoint = loop_sp
          ctes_setpoint = inter_sp
        end
      end

      # Handle overnight charging and discharging
      if ce < cs
        midnight_av = [24, 1]
        midnight_chiller = [24, chg_sp]
        midnight_ctes = [24, loop_sp]
      elsif de < ds
        midnight_av = [24, 1]
        midnight_chiller = [24, chiller_setpoint]
        midnight_ctes = [24, ctes_setpoint]
      else
        midnight_av = [24, 0]
        midnight_chiller = [24, loop_sp]
        midnight_ctes = [24, 99]
      end

      # Availablity k-v sets for CTES
      wk_av = [[cs, 0], [ce, 1], [ds, 0], [de, 1], midnight_av].sort
      wknd_av = [[cs, 0], [ce, 1], midnight_av].sort

      # Temperature k-v sets for CTES
      wk_ctes = [[cs, 99], [ce, loop_sp], [ds, 99], [de, ctes_setpoint], midnight_ctes].sort
      wknd_ctes = [[cs, 99], [ce, loop_sp], midnight_ctes].sort

      # Temperature k-v set for Chiller
      wk_chiller = [[cs, loop_sp], [ce, chg_sp], [ds, loop_sp], [de, chiller_setpoint], midnight_chiller].sort
      wknd_chiller = [[cs, loop_sp], [ce, chg_sp], midnight_chiller].sort

      # Apply weekends modifer if necessary
      if wknds
        wknd_av = wk_av
        wknd_ctes = wk_ctes
        wknd_chiller = wk_chiller
      end

      # Create ice availability schedule
      ruleset_name = 'Ice Availability Schedule (New)'
      winter_design_day = [[24, 0]]
      summer_design_day = wk_av
      default_day = ['AllDays'] + [[24, 0]]
      rules = []
      rules << ['Weekend', ctes_season, 'Sat/Sun'] + wknd_av
      rules << ['Summer Weekday', ctes_season, 'Mon/Tue/Wed/Thu/Fri'] + wk_av
      options_ctes = { 'name' => ruleset_name,
                       'winter_design_day' => winter_design_day,
                       'summer_design_day' => summer_design_day,
                       'default_day' => default_day,
                       'rules' => rules }
      ctes_av_new = OsLib_Schedules.createComplexSchedule(model, options_ctes)
      ctes_av_new.setScheduleTypeLimits(sched_limits_onoff)

      # Create ctes setpoint temperature schedule
      ruleset_name = "#{ctes.name} Setpoint Schedule (New)"
      winter_design_day = [[24, 99]]
      summer_design_day = wk_ctes
      default_day = ['AllDays'] + [[24, 99]]
      rules = []
      rules << ['Weekend', ctes_season, 'Sat/Sun'] + wknd_ctes
      rules << ['Summer Weekday', ctes_season, 'Mon/Tue/Wed/Thu/Fri'] + wk_ctes
      options_ctes_ctes = { 'name' => ruleset_name,
                            'winter_design_day' => winter_design_day,
                            'summer_design_day' => summer_design_day,
                            'default_day' => default_day,
                            'rules' => rules }
      ctes_sch_new = OsLib_Schedules.createComplexSchedule(model, options_ctes_ctes)
      ctes_sch_new.setScheduleTypeLimits(sched_limits_temp)

      # Create chiller setpoint temperature schedule
      ruleset_name = "#{ctes_chiller.name} Setpoint Schedule (New)"
      winter_design_day = [[24, loop_sp]]
      summer_design_day = wk_chiller
      default_day = ['AllDays'] + [[24, loop_sp]]
      rules = []
      rules << ['Weekend', ctes_season, 'Sat/Sun'] + wknd_chiller
      rules << ['Summer Weekday', ctes_season, 'Mon/Tue/Wed/Thu/Fri'] + wk_chiller
      options_ctes_chiller = { 'name' => ruleset_name,
                               'winter_design_day' => winter_design_day,
                               'summer_design_day' => summer_design_day,
                               'default_day' => default_day,
                               'rules' => rules }
      chill_sch_new = OsLib_Schedules.createComplexSchedule(model, options_ctes_chiller)
      chill_sch_new.setScheduleTypeLimits(sched_limits_temp)

      # Create loop setpoint temperature schedule - if new = true
      if new
        ruleset_name = "#{ctes_loop.name} Setpoint Schedule (New)"
        options_ctes_loop = { 'name' => ruleset_name,
                              'winterTimeValuePairs' => [[24, loop_sp]],
                              'summerTimeValuePairs' => [[24, loop_sp]],
                              'defaultTimeValuePairs' => [[24, loop_sp]] }
        loop_sch_new = OsLib_Schedules.createSimpleSchedule(model, options_ctes_loop)
        loop_sch_new.setScheduleTypeLimits(sched_limits_temp)
      end

      # Register info about new schedule objects
      runner.registerInfo("The following schedules were added to the model:\n" \
                          "   * #{ctes_av_new.name}\n" \
                          "   * #{ctes_sch_new.name}\n" \
                          "   * #{chill_sch_new.name}\n" \
                          "   * #{loop_sch_new.name}")

      if old
        runner.registerInfo('However, these schedules are not used in favor of those pre-defined by the user.')
      end

    end
    # end of new schedule build-----------------------------------------------------------------------------------------
    #-------------------------------------------------------------------------------------------------------------------

    ## Create Component Setpoint Objects--------------------------------------------------------------------------------

    if old
      ctes_avail_sched = model.getScheduleRulesetByName(ctes_av).get
      ctes_temp_sched = model.getScheduleRulesetByName(ctes_sch).get
      chill_temp_sched = model.getScheduleRulesetByName(chill_sch).get
    elsif new
      ctes_avail_sched = ctes_av_new
      ctes_temp_sched = ctes_sch_new
      chill_temp_sched = chill_sch_new
    end

    # Apply ice availability schedule
    ctes.setAvailabilitySchedule(ctes_avail_sched)

    # Add component setpoint manager for ice tank
    ctes_sp_mgr = OpenStudio::Model::SetpointManagerScheduled.new(model, ctes_temp_sched)
    ctes_sp_mgr.addToNode(ctes.outletModelObject.get.to_Node.get)
    ctes_sp_mgr.setName("#{ctes.name} Setpoint Manager")

    # Add component setpoint manager for ctes chiller
    chill_sp_mgr = OpenStudio::Model::SetpointManagerScheduled.new(model, chill_temp_sched)
    chill_sp_mgr.addToNode(ctes_chiller.supplyOutletModelObject.get.to_Node.get)
    chill_sp_mgr.setName("#{ctes_chiller.name} Setpoint Manager")

    # Replace existing loop setpoint manager - if new = true and old = false
    if new && !old
      loop_sp_node = ctes_loop.loopTemperatureSetpointNode
      loop_sp_mgrs = loop_sp_node.setpointManagers
      loop_sp_mgrs.each do |spm|
        next unless ['Temperature', 'MinimumTemperature', 'MaximumTemperature'].include?(spm.controlVariable)

        spm.disconnect
        runner.registerInfo("Selected loop temperature setpoint manager '#{spm.name}' " \
                  "with control variable '#{spm.controlVariable}' was disconnected.")
      end

      loop_sp_mgr = OpenStudio::Model::SetpointManagerScheduled.new(model, loop_sch_new)
      loop_sp_mgr.addToNode(loop_sp_node)
      loop_sp_mgr.setName("#{ctes_loop.name} Setpoint Manager (New)")

      demand_sp_mgr = loop_sp_mgr.clone.to_SetpointManagerScheduled.get
      demand_sp_mgr.addToNode(ctes_loop.demandInletNode)
      demand_sp_mgr.setName("#{ctes_loop.name} Demand Side Setpoint Manager (New)")
    end

    # Register info about new schedule objects
    runner.registerInfo('The following component temperature setpoint managers were added to the ' \
                        "model:\n" \
                        "   * #{ctes_sp_mgr.name}\n" \
                        "   * #{chill_sp_mgr.name}")

    if old # Old Schedules always take precedence, even if new ones are also created
      runner.registerInfo("The following schedules ared used in the model:\n" \
                         "   * #{ctes_avail_sched.name}\n" \
                         "   * #{ctes_temp_sched.name}\n" \
                         "   * #{chill_temp_sched.name}")
      runner.registerInfo('The following loop temperature setpoint manager was added to the ' \
                        "model:\n" \
                        "   * #{demand_sp_mgr.name}")
    elsif new && !old
      runner.registerInfo('The following loop temperature setpoint managers were added to the ' \
                         "model:\n" \
                         "   * #{loop_sp_mgr.name}\n" \
                         "   * #{demand_sp_mgr.name}")
    end

    ## Create General EMS Variables for Chiller and TES Capacities------------------------------------------------------

    # Chiller Nominal Capacity Internal Variable
    evar_chiller_cap = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, 'Chiller Nominal Capacity')
    evar_chiller_cap.setInternalDataIndexKeyName(ctes_chiller.name.to_s)
    evar_chiller_cap.setName('CTES_Chiller_Capacity')

    # Ice Tank thermal storage capacity - Empty Global Variable
    evar_tes_cap = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'TES_Cap')

    # Set TES Capacity from User Inputs
    set_tes_cap = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    set_tes_cap.setName('Set_TES_Cap')
    body = <<-EMS
      SET TES_Cap = #{storage_capacity}
    EMS
    set_tes_cap.setBody(body)

    set_tes_cap_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    set_tes_cap_pcm.setName('Set_TES_Cap_CallMgr')
    set_tes_cap_pcm.setCallingPoint('BeginNewEnvironment')
    set_tes_cap_pcm.addProgram(set_tes_cap)

    ## Create EMS Components to Control Load on Upstream (Priority) Device----------------------------------------------

    # Flag value indicating that a chiller limiter is required or DR Test is Activated
    if chiller_limit < 1.0 || dr == true

      # Set up EMS output
      output_ems = model.getOutputEnergyManagementSystem
      output_ems.setActuatorAvailabilityDictionaryReporting('Verbose')
      output_ems.setInternalVariableAvailabilityDictionaryReporting('Verbose')
      output_ems.setEMSRuntimeLanguageDebugOutputLevel('None')

      runner.registerInfo("A #{(chiller_limit * 100).round(2)}% capacity limit has been placed on the chiller " \
                        'during ice discharge. EMS scripting is employed to actuate this control via chiller ' \
                        'outlet setpoint. ')

      # Internal and Global Variable(s)

      # Chiller Limited Capacity for Ice Discharge Period - Empty Global Variable
      evar_chiller_limit = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'Chiller_Limited_Capacity')

      # Instances of Chiller Limit Application - Empty Global Variable
      evar_limit_counter = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'Limit_Counter')

      # Max Delta-T for Chiller De-Rate - Empty Global Variable
      dt_ems = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'DT_Max')

      # DR In-Progress Flag - Empty Global Variable
      dr_flag = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'DR_Flag')

      # Sensor(s)
      # Evaporator Entering Water Temperature
      eewt = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Chiller Evaporator Inlet Temperature')
      eewt.setName('EEWT')
      eewt.setKeyName(ctes_chiller.name.to_s)

      # Evaporator Leaving Water Temperature
      elwt = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Chiller Evaporator Outlet Temperature')
      elwt.setName('ELWT')
      elwt.setKeyName(ctes_chiller.name.to_s)

      # Evaporator Leave Water Temperature Setpoint
      elwt_sp = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
      elwt_sp.setName('SP')
      elwt_sp.setKeyName(chill_temp_sched.name.to_s)

      # Supply Water Temperature Setpoint
      swt_sp = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Setpoint Temperature')
      swt_sp.setName('SWT_SP')
      swt_sp.setKeyName(ctes_loop.supplyOutletNode.name.to_s)

      # Ice Tank Availability Schedule
      av_sp = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
      av_sp.setName('ICE_AV')
      av_sp.setKeyName(ctes.availabilitySchedule.get.name.to_s)

      # Ice Tank Leaving Water Temperature
      ilwt = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Temperature')
      ilwt.setName('ILWT')
      ilwt.setKeyName(ctes.outletModelObject.get.name.to_s)

      # Ice Tank State of Charge
      soc = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Ice Thermal Storage End Fraction')
      soc.setName('SOC')
      soc.setKeyName(ctes.name.to_s)

      # Actuator(s)
      # Evaporator Leaving Water Temperature Septoint Node Actuator
      elwt = OpenStudio::Model::EnergyManagementSystemActuator.new(ctes_chiller.supplyOutletModelObject.get,
                                                                   'System Node Setpoint', 'Temperature Setpoint')
      elwt.setName('ELWT_SP')
    end

    if chiller_limit < 1.0
      # Program(s)
      # Apply Chiller Capacity Limit During Ice Discharge
      chiller_limit_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      chiller_limit_program.setName('Chiller_Limiter')
      body = <<-EMS
  		IF ( ICE_AV == 1 ) && ( SP >= SWT_SP ) && ( DR_Flag <> 1 )
  		 	IF ( EEWT - SP ) > DT_Max
  		    	SET ELWT_SP = ( EEWT - DT_Max )
  		    	SET Limit_Counter = ( Limit_Counter + ( SystemTimeStep / ZoneTimeStep ) )
  		  	ELSE
  		    	SET ELWT_SP = SP
  		  	ENDIF
  		ELSE
  		  	SET ELWT_SP = SP
  		ENDIF
      EMS
      chiller_limit_program.setBody(body)

      # Determine Capacity Limit of the Chiller in Watts (Also initializes limit counter)
      chiller_limit_calculation = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      chiller_limit_calculation.setName('Chiller_Limit_Calc')
      body = <<-EMS
  			SET Chiller_Limited_Capacity = ( #{chiller_limit} * CTES_Chiller_Capacity )
  			SET Limit_Counter = 0
  			SET DR_Flag = 0
        SET DT_Max = #{dt_max}
      EMS
      chiller_limit_calculation.setBody(body)

      # Program Calling Manager(s)
      chiller_limit_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      chiller_limit_pcm.setName('Chiller_Limiter_CallMgr')
      chiller_limit_pcm.setCallingPoint('InsideHVACSystemIterationLoop')
      chiller_limit_pcm.addProgram(chiller_limit_program)

      chiller_limit_calc_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      chiller_limit_calc_pcm.setName('Chiller_Limit_Calc_CallMgr')
      chiller_limit_calc_pcm.setCallingPoint('BeginNewEnvironment')
      chiller_limit_calc_pcm.addProgram(chiller_limit_calculation)

      # EMS Output Variable(s) - Chiller Limiter Dependent
      eout_chiller_limit = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, evar_chiller_limit)
      eout_chiller_limit.setName('Chiller Limited Capacity')

      eout_limit_counter = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, evar_limit_counter)
      eout_limit_counter.setName('Chiller Limit Counter')

    end

    ## DR EVENT TESTER EMS --------------------------
    ## Add Demand Response Event Tester if Applicable (EMS Controller Override)-----------------------------------------

    if dr

      # Create EMS Script that:
      # => 1. Determines if DR Event has been triggered (inspects date/time)
      # => 2. Actuates full storage if in a Load Shed DR event
      # => 3. Actuates ice charging/chiller @ max if in a Load Add DR event
      # => 4. Allows staged chiller ramp if ice runs out (if selected by user)

      # Create DR EMS Program
      dr_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      dr_program.setName('Demand_Response_Pgm')

      # Define Program Script Based on Permission of Chiller to Operate to Meet Load
      if dr_chill && dr_add_shed == 'Shed'	# Chiller is permitted to pick up unmet load
        body = <<-EMS
			IF ( Month == #{dr_mon} ) && ( DayOfMonth == #{dr_day} )
				IF ( CurrentTime > #{dr_time} ) && ( CurrentTime <= #{dr_time + dr_dur} )
					SET DR_Flag = 1
          IF ( ILWT - SWT_SP < 0.05 )
					  SET ELWT_SP = EEWT
          ELSEIF ( ILWT - SWT_SP <= 0.33 * DT_Max )
            SET ELWT_SP = EEWT - ( 0.33 * DT_Max )
          ELSEIF ( ILWT - SWT_SP <= 0.67 * DT_Max )
            SET ELWT_SP = EEWT - ( 0.67 * DT_Max )
          ELSE
            SET ELWT_SP = ( EEWT - DT_Max )
            SET Limit_Counter = ( Limit_Counter + ( SystemTimeStep / ZoneTimeStep ) )
					ENDIF
				ELSEIF ( DR_Flag == 1 )
					SET DR_Flag = 0
          SET ELWT_SP = SP
				ENDIF
			ENDIF
        EMS
        dr_program.setBody(body)
      elsif !dr_chill && dr_add_shed == 'Shed'	# Chiller is not permitted to pick up unmet load when ice is deficient
        body = <<-EMS
			IF ( Month == #{dr_mon} ) && ( DayOfMonth == #{dr_day} )
				IF ( CurrentTime > #{dr_time} ) && ( CurrentTime <= #{dr_time + dr_dur} )
					SET DR_Flag = 1
					SET ELWT_SP = EEWT + 10.0
				ELSEIF ( DR_Flag == 1 )
					SET DR_Flag = 0
				ENDIF
			ENDIF
        EMS
        dr_program.setBody(body)
      elsif dr_add_shed == 'Add'
        body = <<-EMS
      IF ( Month == #{dr_mon} ) && ( DayOfMonth == #{dr_day} )
				IF ( CurrentTime > #{dr_time} ) && ( CurrentTime <= #{dr_time + dr_dur} )
          SET DR_Flag = 1
          IF ( SOC < 0.99 ) && ( ICE_AV == 1 )
            SET ELWT_SP = #{chg_sp}
          ELSEIF SOC > 0.95
            SET ELWT_SP = SWT_SP
          ENDIF
        ELSEIF ( DR_Flag == 1 )
          SET DR_Flag = 0
        ENDIF
      ENDIF
        EMS
        dr_program.setBody(body)
      end

      # Create DR EMS Program Calling Manager
      dr_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      dr_pcm.setName('Demand_Response_PCM')
      dr_pcm.setCallingPoint('InsideHVACSystemIterationLoop')
      dr_pcm.addProgram(dr_program)

      # EMS Output Variable(s)
      eout_drflag = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, dr_flag)
      eout_drflag.setName('Demand Response Flag')
    end
    ## END DR EVENT TESTER EMS ---------------------

    ## Add Output Variables and Meters----------------------------------------------------------------------------------

    # EMS Output Variable(s) - Chiller Limit Independent
    eout_chiller_cap = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, evar_chiller_cap)
    eout_chiller_cap.setName('Chiller Nominal Capacity')

    eout_tes_cap = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, evar_tes_cap)
    eout_tes_cap.setName('Ice Thermal Storage Capacity')

    # Identify existing output variables
    vars = model.getOutputVariables
    var_names = []
    vars.each do |v|
      var_names << v.variableName
    end

    # List names of desired output variables
    ovar_names = ['Ice Thermal Storage Cooling Rate',
                  'Ice Thermal Storage Cooling Charge Rate',
                  'Ice Thermal Storage Cooling Discharge Rate',
                  'Ice Thermal Storage Cooling Charge Energy',
                  'Ice Thermal Storage Cooling Discharge Energy',
                  'Ice Thermal Storage Cooling Discharge Energy',
                  'Ice Thermal Storage End Fraction',
                  'Ice Thermal Storage On Coil Fraction',
                  'Ice Thermal Storage Mass Flow Rate',
                  'Ice Thermal Storage Tank Mass Flow Rate',
                  'Ice Thermal Storage Bypass Mass Flow Rate',
                  'Ice Thermal Storage Fluid Inlet Temperature',
                  'Ice Thermal Storage Tank Outlet Temperature',
                  'Ice Thermal Storage Blended Outlet Temperature',
                  'Ice Thermal Storage Ancillary Electric Power',
                  'Ice Thermal Storage Ancillary Electric Energy',
                  'Chiller COP',
                  'Chiller Cycling Ratio',
                  'Chiller Part Load Ratio',
                  'Chiller Electric Power',
                  'Chiller Electric Energy',
                  'Chiller Evaporator Cooling Rate',
                  'Chiller Evaporator Cooling Energy',
                  'Chiller Condenser Heat Transfer Rate',
                  'Chiller Condenser Heat Transfer Energy',
                  'Chiller False Load Heat Transfer Rate',
                  'Chiller False Load Heat Transfer Energy',
                  'Chiller Evaporator Inlet Temperature',
                  'Chiller Evaporator Outlet Temperature',
                  'Chiller Evaporator Mass Flow Rate',
                  'Site Outdoor Air Drybulb Temperature',
                  'Site Outdoor Air Wetbulb Temperature']

    # Create new output variables if they do not already exist
    ovars = []
    ovar_names.each do |nm|
      # if !var_names.include?(nm)
      ovars << OpenStudio::Model::OutputVariable.new(nm, model)
      # end
    end

    # Create output variable for loop demand inlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes_loop.demandInletNode.name.to_s)
    ovars << v

    # Create output variable for loop demand outlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes_loop.demandOutletNode.name.to_s)
    ovars << v

    # Create output variable for loop supply inlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes_loop.supplyInletNode.name.to_s)
    ovars << v

    # Create output variable for loop supply outlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes_loop.supplyOutletNode.name.to_s)
    ovars << v

    # Create output variable for chiller inlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes_chiller.supplyInletModelObject.get.name.to_s)
    ovars << v

    # Create output variable for chiller outlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes_chiller.supplyOutletModelObject.get.name.to_s)
    ovars << v

    # Create output variable for ice tank inlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes.inletModelObject.get.name.to_s)
    ovars << v

    # Create output variable for ice tank outlet temperature
    v = OpenStudio::Model::OutputVariable.new('System Node Temperature', model)
    v.setKeyValue(ctes.outletModelObject.get.name.to_s)
    ovars << v

    # Create output variables for the new operating schedules
    v = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    v.setKeyValue(ctes_avail_sched.name.to_s)
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    v.setKeyValue(ctes_temp_sched.name.to_s)
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    v.setKeyValue(chill_temp_sched.name.to_s)
    ovars << v

    # Create output variable for plant loop setpoint temperature - if new = true
    if new
      v = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
      v.setKeyValue(loop_sch_new.name.to_s)
      ovars << v
    end

    # Create output variables for ice discharge performance curve
    v = OpenStudio::Model::OutputVariable.new('Performance Curve Input Variable 1 Value', model)
    v.setKeyValue(ctes.dischargingCurve.name.to_s)
    v.setName('Discharge Curve Input Value 1')
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Performance Curve Input Variable 2 Value', model)
    v.setKeyValue(ctes.dischargingCurve.name.to_s)
    v.setName('Discharge Curve Input Value 2')
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Performance Curve Output Value', model)
    v.setKeyValue(ctes.dischargingCurve.name.to_s)
    v.setName('Discharge Curve Output Value')
    ovars << v

    # Create output variables for ice charge performance curve
    v = OpenStudio::Model::OutputVariable.new('Performance Curve Input Variable 1 Value', model)
    v.setKeyValue(ctes.chargingCurve.name.to_s)
    v.setName('Charge Curve Input Value 1')
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Performance Curve Input Variable 2 Value', model)
    v.setKeyValue(ctes.chargingCurve.name.to_s)
    v.setName('Charge Curve Input Value 2')
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Performance Curve Output Value', model)
    v.setKeyValue(ctes.chargingCurve.name.to_s)
    v.setName('Charge Curve Output Value')
    ovars << v

    # Create output variables for chiller performance
    v = OpenStudio::Model::OutputVariable.new('Performance Curve Output Value', model)
    v.setKeyValue(ctes_chiller.coolingCapacityFunctionOfTemperature.name.to_s)
    v.setName('Charge Curve Output Value')
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Performance Curve Output Value', model)
    v.setKeyValue(ctes_chiller.electricInputToCoolingOutputRatioFunctionOfTemperature.name.to_s)
    v.setName('Charge Curve Output Value')
    ovars << v

    v = OpenStudio::Model::OutputVariable.new('Performance Curve Output Value', model)
    v.setKeyValue(ctes_chiller.electricInputToCoolingOutputRatioFunctionOfPLR.name.to_s)
    v.setName('Charge Curve Output Value')
    ovars << v

    if chiller_limit < 1.0 # flag for EMS use, following EMS vars only exist if previous script ran

      # Create output variable for chiller limited capacity (from EMS Output Variable)
      v = OpenStudio::Model::OutputVariable.new(eout_chiller_limit.name.to_s, model)
      v.setName("#{ctes_chiller.name} Limited Capacity")
      v.setVariableName('Chiller Limited Capacity')
      ovars << v

      # Create output variable for chiller limit counter (from EMS Output Variable)
      v = OpenStudio::Model::OutputVariable.new(eout_limit_counter.name.to_s, model)
      v.setName("#{ctes_chiller.name} Limit Counter [Zone Timesteps]")
      v.setVariableName('Chiller Limit Counter')
      ovars << v

    end

    # Create output variable for Demand Response Flag (from EMS Output Variable)
    if dr

      v = OpenStudio::Model::OutputVariable.new(eout_drflag.name.to_s, model)
      v.setName('Demand Response Event Flag')
      v.setVariableName('Demand Response Flag')
      ovars << v

    end

    # Create output variable for TES Capacity (from EMS Global Variable)
    v = OpenStudio::Model::OutputVariable.new(eout_tes_cap.name.to_s, model)
    v.setName("#{ctes.name} Ice Thermal Storage Capacity [GJ]")
    v.setVariableName('Ice Thermal Storage Capacity')
    ovars << v

    # Create output variable for chiller nominal capacity (from EMS Output Variable)
    v = OpenStudio::Model::OutputVariable.new(eout_chiller_cap.name.to_s, model)
    v.setName("#{ctes_chiller.name} Nominal Capacity [W]")
    v.setVariableName('Chiller Nominal Capacity')
    ovars << v

    # Set variable reporting frequency for newly created output variables
    ovars.each do |var|
      var.setReportingFrequency(report_freq)
    end

    # Register info about new output variables
    runner.registerInfo("#{ovars.size} chiller and ice storage output variables were added to the model.")

    # Create new energy/specific end use meters
    omet_names = ['Pumps:Electricity',
                  'Fans:Electricity',
                  'Cooling:Electricity',
                  'Electricity:HVAC',
                  'Electricity:Plant',
                  'Electricity:Building',
                  'Electricity:Facility']

    omet_names.each do |nm|
      omet = OpenStudio::Model::OutputMeter.new(model)
      omet.setName(nm)
      omet.setReportingFrequency(report_freq)
      omet.setMeterFileOnly(false)
      omet.setCumulative(false)
    end

    # Register info about new output meters
    runner.registerInfo("#{omet_names.size} output meters were added to the model.")

    ## Report Final Condition of Model----------------------------------------------------------------------------------
    total_storage = model.getThermalStorageIceDetaileds.size
    runner.registerFinalCondition("The model finished with #{total_storage} ice energy storage device(s).")

    true
  end
end

# register the measure to be used by the application
AddCentralIceStorage.new.registerWithApplication
