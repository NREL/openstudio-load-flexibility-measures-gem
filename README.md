# Openstudio Load Flexibility Measures Gem

This gem contains measures for thermal energy storage for building cooling and domestic hot water heating.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-load-flexibility-measures'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'openstudio-load-flexibility-measures'

## Usage

The openstudio-load-flexibility-measures gem contains measures to apply thermal load flexibility to a building model. The current version contains the following:
* Add [HPHW](https://github.com/NREL/openstudio-load-flexibility-measures-gem/tree/master/lib/measures/add_hpwh) (Heat Pump Hot Water Heater)
* Add [Central Ice Storage](https://github.com/NREL/openstudio-load-flexibility-measures-gem/tree/master/lib/measures/add_central_ice_storage) (for plant loops)
* Add [Packaged Ice Storage](https://github.com/NREL/openstudio-load-flexibility-measures-gem/tree/master/lib/measures/add_packaged_ice_storage) (for rooftop units)

Detailed instructions for usage are included in each measure's respective README.md and docs folder. 

# Compatibility Matrix

|OpenStudio Load Flexibility Measures Gem|OpenStudio|Ruby|
|:--------------:|:----------:|:--------:|
| 0.11.1| 3.10     | 3.2.2  |
| 0.11.0| 3.10     | 3.2.2  |
| 0.10.1| 3.9      | 3.2.2  |
| 0.10.0| 3.9      | 3.2.2  |
| 0.9.0| 3.8      | 3.2.2  |
| 0.8.0| 3.7      | 2.7    |
| 0.7.0| 3.6      | 2.7    |
| 0.6 - 0.6.1 | 3.5      | 2.7    |
| 0.5  | 3.4      | 2.7    |
| 0.4  | 3.2      | 2.7    |
| 0.3.2  | 3.2      | 2.7    |
| 0.2.0 - 0.2.1  | 3.1      | 2.5    |
| 0.1.1 - 0.1.3  | 3.0      | 2.5    |


# Contributing

Please review the [OpenStudio Contribution Policy](https://openstudio.net/openstudio-contribution-policy) if you would like to contribute code to this gem.

## Local Testing

To test the GitHub Actions workflow locally using `act`, see the [Local Testing Guide](docs/LOCAL_TESTING.md).

# Releasing

* Update `CHANGELOG.md`
* Run `rake rubocop:auto_correct`
* Run `rake openstudio:update_copyright`
* Run `rake openstudio:update_measures` (this has to be done last since prior tasks alter measure files)
* Update version in `readme.md`
* Review dependency versions in `openstudio-load-flexibility.gemspec` (especially openstudio-standards and openstudio-extension)
* Update version in `/lib/openstudio/load-flexibility/version.rb`. Do not create a patch release if there are breaking changes or if this new version will support a biannual OpenStudio release; make a "minor" release instead. (ex: going from 0.7.0 to 0.8.0)
* Create PR to master, after tests and reviews complete, then merge
* Locally - from the master branch, run `rake release`
* On GitHub, go to the releases page and update the latest release tag. Name it “Version x.y.z” and copy the CHANGELOG entry into the description box.

