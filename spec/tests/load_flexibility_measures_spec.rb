# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require_relative '../spec_helper'

RSpec.describe OpenStudio::LoadFlexibilityMeasures do
  it 'has a version number' do
    expect(OpenStudio::LoadFlexibilityMeasures::VERSION).not_to be nil
  end

  it 'has a measures directory' do
    instance = OpenStudio::LoadFlexibilityMeasures::LoadFlexibilityMeasures.new
    expect(File.exist?(instance.measures_dir)).to be true
  end
end
