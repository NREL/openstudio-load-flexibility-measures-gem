# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure'

class AddPackagedIceStorageTest < MiniTest::Test
  # def setup
  # end

  # def teardown
  # end

  # Runs an annual simulation of IDF
  #
  # code based on model_run_simulation_and_log_errors from OpenStudio Standards
  # Maybe update method above to optionally take IDF instead of OSM or add another method
  #
  # @param IDF OpenStudio workspace IDF object
  # @param run_dir [String] file path location for the annual run, defaults to 'Run' in the current directory
  # @return [Bool] returns true if successful, false if not
  def model_run_simulation_and_log_errors(model, workspace, run_dir = "#{Dir.pwd}/Run")
    # Make the directory if it doesn't exist
    unless Dir.exist?(run_dir)
      FileUtils.mkdir_p(run_dir)
    end

    # Save workspace IDF
    idf_name = 'in.idf'
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', "Starting simulation here: #{run_dir}.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Running simulation #{run_dir}.")
    idf_path = OpenStudio::Path.new("#{run_dir}/#{idf_name}")
    workspace.save(idf_path, true)

    # Set up the simulation
    # Find the weather file
    epw_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw")

    sql_path = nil

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', 'Running with RunManager.')

    # Find EnergyPlus
    ep_path = OpenStudio.getEnergyPlusExecutable

    puts "EnergyPlus is: #{ep_path}"
    job = "energyplus -w #{epw_path.to_s} -d #{run_dir} #{idf_path.to_s}"
    puts job
    system(job)

    sql_path = OpenStudio::Path.new("#{run_dir}/eplusout.sql")

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')

    # @todo Delete the eplustbl.htm and other files created by the run for cleanliness.

    if OpenStudio.exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
      # Check to make sure the sql file is readable,
      # which won't be true if EnergyPlus crashed during simulation.
      unless sql.connectionOpen
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed, cannot create model.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
        return false
      end
    else
      # If the sql file does not exist, it is likely that EnergyPlus crashed,
      # in which case the useful errors are inside the eplusout.err file.
      err_file_path_string = "#{run_dir}/eplusout.err"
      err_file_path = OpenStudio::Path.new(err_file_path_string)
      if OpenStudio.exists(err_file_path)
        if __dir__[0] == ':' # Running from OpenStudio CLI
          errs = EmbeddedScripting.getFileAsString(err_file_path_string)
        else
          errs = File.read(err_file_path_string)
        end
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run did not finish because of the following errors: #{errs}")
        return false
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the run couldn't be found here: #{sql_path}.")
        return false
      end
    end

    # Report severe or fatal errors in the run
    error_query = "SELECT ErrorMessage
        FROM Errors
        WHERE ErrorType in(1,2)"
    model.setSqlFile(sql)
    errs = model.sqlFile.get.execAndReturnVectorOfString(error_query)
    if errs.is_initialized
      errs = errs.get
    end

    # Check that the run completed successfully
    end_file_stringpath = "#{run_dir}/eplusout.end"
    end_file_path = OpenStudio::Path.new(end_file_stringpath)
    if OpenStudio.exists(end_file_path)
      endstring = File.read(end_file_stringpath)
    end

    if !endstring.include?('EnergyPlus Completed Successfully')
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run did not finish and had following errors: #{errs.join('\n')}")
      return false
    end

    # Log any severe errors that did not cause simulation to fail
    unless errs.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The run completed but had the following severe errors: #{errs.join('\n')}")
    end

    return true
  end  

  def test_good_argument_values
    # create an instance of the measure
    measure = AddPackagedIceStorage.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/MeasureTest.osm")
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    args_hash['ice_cap'] = '40,50'

    # populate argument with specified has value if set
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(args_hash[arg.name])) if args_hash[arg.name]
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(workspace, runner, argument_map)

    # run the annual simulation
    # commented out for now E+ run in test doesn't function on CI yet
    #output_file_path = "#{File.dirname(__FILE__)}/output/test_good_argument_values"
    #sim_results = self.model_run_simulation_and_log_errors(model, workspace, output_file_path)
    #assert(sim_results)

    result = runner.result
    assert_equal('Success', result.value.valueName)

    show_output(result)

    true
  end

  def test_single_speed_dx
    # create an instance of the measure
    measure = AddPackagedIceStorage.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/single_speed_dx_350.osm")
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    #args_hash['ice_cap'] = '40,50'

    # populate argument with specified has value if set
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(args_hash[arg.name])) if args_hash[arg.name]
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(workspace, runner, argument_map)

    # run the annual simulation
    # commented out for now E+ run in test doesn't function on CI yet
    #output_file_path = "#{File.dirname(__FILE__)}/output/single_speed_dx"
    #sim_results = self.model_run_simulation_and_log_errors(model, workspace, output_file_path)
    #assert(sim_results)

    result = runner.result
    assert_equal('Success', result.value.valueName)

    show_output(result)

    true
  end
end
