# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'csv'

# start the measure
class GEBAppliancesPeakPeriodShift < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'GEBAppliancesPeakPeriodShift'
  end

  # human readable description
  def description
    return 'TODO'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'TODO'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument('schedules_peak_period', true)
    arg.setDisplayName('Schedules: Peak Period')
    arg.setDescription('Specifies the peak period. Enter a time like "15 - 18" (start hour can be 0 through 23 and end hour can be 1 through 24).')
    arg.setDefaultValue('15 - 18')
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeIntegerArgument('schedules_peak_period_delay', true)
    arg.setDisplayName('Schedules: Peak Period Delay')
    arg.setUnits('hr')
    arg.setDescription('The number of hours after peak period end.')
    arg.setDefaultValue(0)
    args << arg

    schedule_files = model.getScheduleFiles.sort_by { |s| s.name.to_s }
    schedule_files.each do |schedule_file|
      arg = OpenStudio::Measure::OSArgument::makeBoolArgument("schedules_peak_period_#{schedule_file.name}", true)
      arg.setDisplayName("Schedules: Peak Period #{schedule_file.name}")
      arg.setDescription("Whether to shift the #{schedule_file.name} schedule during the peak period.")
      arg.setDefaultValue(false)
      args << arg
    end

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)  # Do **NOT** remove this line

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    schedules_peak_period = runner.getStringArgumentValue('schedules_peak_period', user_arguments)
    schedules_peak_period_delay = runner.getIntegerArgumentValue('schedules_peak_period_delay', user_arguments)

    schedule_files = {}
    model.getScheduleFiles.sort_by { |s| s.name.to_s }.each do |schedule_file|
      schedule_files[schedule_file.name.to_s] = runner.getBoolArgumentValue("schedules_peak_period_#{schedule_file.name}", user_arguments)
    end

    if schedule_files.empty? || schedule_files.values.all? { |value| value == false }
      runner.registerAsNotApplicable('Did not select any ScheduleFile objects to shift.')
      return true
    end

    # TODO: use schedule_files, schedules_peak_period, schedules_peak_period_delay to shift referenced ScheduleFile objects
    # 1 create ScheduleFile class for loading externalFile into hash
    # 2 do the operations from https://github.com/NREL/OpenStudio-HPXML/pull/1293 on applicable columns
    # 3 overwrite (export) the csv file
    model.getExternalFiles.each do |external_file|
      csv_file = CSV.read(external_file.filePath.to_s)
    end

    return true
  end
end

# register the measure to be used by the application
GEBAppliancesPeakPeriodShift.new.registerWithApplication
