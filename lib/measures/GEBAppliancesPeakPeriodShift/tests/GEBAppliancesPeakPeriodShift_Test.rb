# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class GEBAppliancesPeakPeriodShiftTest < Minitest::Test
  def test_GEBAppliancesPeakPeriodShift
    # create an instance of the measure
    measure = GEBAppliancesPeakPeriodShift.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/base-schedules-detailed-occupancy-stochastic.osm')
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(13, arguments.size)

    count = -1

    assert_equal('schedules_peak_period', arguments[count += 1].name)
    assert_equal('schedules_peak_period_delay', arguments[count += 1].name)
    assert_equal('schedules_peak_period_clothes_dryer', arguments[count += 1].name)
    assert_equal('schedules_peak_period_clothes_washer', arguments[count += 1].name)
    assert_equal('schedules_peak_period_cooking_range', arguments[count += 1].name)
    assert_equal('schedules_peak_period_dishwasher', arguments[count += 1].name)
    assert_equal('schedules_peak_period_hot_water_clothes_washer', arguments[count += 1].name)
    assert_equal('schedules_peak_period_hot_water_dishwasher', arguments[count += 1].name)
    assert_equal('schedules_peak_period_hot_water_fixtures', arguments[count += 1].name)
    assert_equal('schedules_peak_period_lighting_interior', arguments[count += 1].name)
    assert_equal('schedules_peak_period_occupants', arguments[count += 1].name)
    assert_equal('schedules_peak_period_plug_loads_other', arguments[count += 1].name)
    assert_equal('schedules_peak_period_plug_loads_tv', arguments[count += 1].name)    

    # set argument values to good values and run the measure on model with spaces
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    count = -1

    schedules_peak_period = arguments[count += 1].clone
    assert(schedules_peak_period.setValue('15 - 18'))
    argument_map['schedules_peak_period'] = schedules_peak_period

    schedules_peak_period_delay = arguments[count += 1].clone
    assert(schedules_peak_period_delay.setValue(1))
    argument_map['schedules_peak_period_delay'] = schedules_peak_period_delay

    schedules_peak_period_clothes_dryer = arguments[count += 1].clone
    assert(schedules_peak_period_clothes_dryer.setValue(true))
    argument_map['schedules_peak_period_clothes_dryer'] = schedules_peak_period_clothes_dryer

    schedules_peak_period_clothes_washer = arguments[count += 1].clone
    assert(schedules_peak_period_clothes_washer.setValue(true))
    argument_map['schedules_peak_period_clothes_washer'] = schedules_peak_period_clothes_washer

    # before
    # 1 instantiate the SchedulesFile
    model.getScheduleFiles.each do |schedule_file|
      if schedule_file.name.to_s.include?('clothes_dryer')
        columns = CSV.read(File.dirname(__FILE__) + "/files/#{schedule_file.externalFile.fileName}").transpose
      elsif schedule_file.name.to_s.include?('clothes_washer')
      end
    end

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == 'Success')
    assert(result.warnings.empty?)
    assert(result.info.size == 0)

    # after
    # 2 instantiate the SchedulesFile
    # 3 compare before's hash to after's hash

    # save the model
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + '/test_GEBAppliancesPeakPeriodShift.osm')
    model.save(output_file_path, true)
  end
end
