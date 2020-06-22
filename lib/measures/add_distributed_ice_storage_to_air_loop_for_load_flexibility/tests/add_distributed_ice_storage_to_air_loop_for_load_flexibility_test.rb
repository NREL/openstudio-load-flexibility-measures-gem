require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

class AddDistributedIceStorageToAirLoopForLoadFlexibility_Test < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  def test_good_argument_values

    # create an instance of the measure
    measure = AddDistributedIceStorageToAirLoopForLoadFlexibility.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/MeasureTest.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    args_hash["ice_cap"] = "40,50"

    # populate argument with specified has value if set
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    assert_equal("Success", result.value.valueName)

    show_output(result)

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.idf")
    workspace.save(output_file_path,true)

    return true

  end

end
