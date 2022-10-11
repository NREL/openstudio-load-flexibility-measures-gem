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

module OsLib_Schedules
  # create a ruleset schedule with a basic profile
  def self.createSimpleSchedule(model, options = {})
    defaults = {
      'name' => nil,
      'winterTimeValuePairs' => { 24.0 => 0.0 },
      'summerTimeValuePairs' => { 24.0 => 1.0 },
      'defaultTimeValuePairs' => { 24.0 => 1.0 }
    }

    # merge user inputs with defaults
    options = defaults.merge(options)

    # ScheduleRuleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    sch_ruleset.setName(options['name']) if name

    # Winter Design Day
    winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
    winter_dsn_day = sch_ruleset.winterDesignDaySchedule
    winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")
    options['winterTimeValuePairs'].each do |k, v|
      hour = k.truncate
      min = ((k - hour) * 60).to_i
      winter_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), v)
    end

    # Summer Design Day
    summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
    summer_dsn_day = sch_ruleset.summerDesignDaySchedule
    summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")
    options['summerTimeValuePairs'].each do |k, v|
      hour = k.truncate
      min = ((k - hour) * 60).to_i
      summer_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), v)
    end

    # All Days
    week_day = sch_ruleset.defaultDaySchedule
    week_day.setName("#{sch_ruleset.name} Schedule Week Day")
    options['defaultTimeValuePairs'].each do |k, v|
      hour = k.truncate
      min = ((k - hour) * 60).to_i
      week_day.addValue(OpenStudio::Time.new(0, hour, min, 0), v)
    end

    sch_ruleset
  end

  # create a complex ruleset schedule
  def self.createComplexSchedule(model, options = {})
    defaults = {
      'name' => nil,
      'default_day' => ['always_on', [24.0, 1.0]]
    }

    # merge user inputs with defaults
    options = defaults.merge(options)

    # ScheduleRuleset
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    sch_ruleset.setName(options['name']) if name

    # Winter Design Day
    unless options['winter_design_day'].nil?
      winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
      winter_dsn_day = sch_ruleset.winterDesignDaySchedule
      winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")
      options['winter_design_day'].each do |data_pair|
        hour = data_pair[0].truncate
        min = ((data_pair[0] - hour) * 60).to_i
        winter_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
      end
    end

    # Summer Design Day
    unless options['summer_design_day'].nil?
      summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
      summer_dsn_day = sch_ruleset.summerDesignDaySchedule
      summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")
      options['summer_design_day'].each do |data_pair|
        hour = data_pair[0].truncate
        min = ((data_pair[0] - hour) * 60).to_i
        summer_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
      end
    end

    # Default Day
    default_day = sch_ruleset.defaultDaySchedule
    default_day.setName("#{sch_ruleset.name} #{options['default_day'][0]}")
    default_data_array = options['default_day']
    default_data_array.delete_at(0)
    default_data_array.each do |data_pair|
      hour = data_pair[0].truncate
      min = ((data_pair[0] - hour) * 60).to_i
      default_day.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
    end

    # Rules
    unless options['rules'].nil?
      options['rules'].each do |data_array|
        rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        rule.setName("#{sch_ruleset.name} #{data_array[0]} Rule")
        date_range = data_array[1].split('-')
        start_date = date_range[0].split('/')
        end_date = date_range[1].split('/')
        rule.setStartDate(model.getYearDescription.makeDate(start_date[0].to_i, start_date[1].to_i))
        rule.setEndDate(model.getYearDescription.makeDate(end_date[0].to_i, end_date[1].to_i))
        days = data_array[2].split('/')
        rule.setApplySunday(true) if days.include? 'Sun'
        rule.setApplyMonday(true) if days.include? 'Mon'
        rule.setApplyTuesday(true) if days.include? 'Tue'
        rule.setApplyWednesday(true) if days.include? 'Wed'
        rule.setApplyThursday(true) if days.include? 'Thu'
        rule.setApplyFriday(true) if days.include? 'Fri'
        rule.setApplySaturday(true) if days.include? 'Sat'
        day_schedule = rule.daySchedule
        day_schedule.setName("#{sch_ruleset.name} #{data_array[0]}")
        data_array.delete_at(0)
        data_array.delete_at(0)
        data_array.delete_at(0)
        data_array.each do |data_pair|
          hour = data_pair[0].truncate
          min = ((data_pair[0] - hour) * 60).to_i
          day_schedule.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
        end
      end
    end

    sch_ruleset
  end
end
