# OpenStudio Load Flexibility Measures Gem

## Version 0.11.0
* Support for OpenStudio 3.10 (upgrade to standards gem 0.8.2, extension gem 0.9.1)
* todo add log after finalize bug fixes for this release

## Version 0.10.1
* Update dependencies for 3.9

## Version 0.10.0
- Support for OpenStudio 3.9 (upgrade to standards gem 0.7.0, extension gem 0.8.1)

## Version 0.9.0
- Updating dependencies and licenses for OpenStudio 3.8 (upgrade to standards gem 0.6.0)

## Version 0.8.0
- Updating dependencies and licenses for OpenStudio 3.7 (upgrade to standards gem 0.5.0, extension gem 0.7.0)
- Fix field indexes for CoilCoolingDXTwoSpeed in add_packaged_ice_storage

## Version 0.7.0
- Updating dependencies and licenses for OpenStudio 3.6 (upgrade to standards gem 0.4.0, extension gem 0.6.1)

## Version 0.6.1
- Fixing E+ run using Coil:Cooling:DX:SingleSpeed:ThermalStorage in Packaged Ice Storage Measure [#52](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/52)

## Version 0.6.0
- Support for OpenStudio 3.5 (upgrade to standards gem 0.3.0, extension gem 0.6.0)

## Version 0.5.1
- Added the ShiftScheduleByType measure - [#47](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/47)
- Updating licenses and measure versions / checksums for 2022

## Version 0.5.0
* Updated OS Standards dependency to 0.2.16
* Fixed [#41](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/41), Error in applying add_hpwh measure with "non-simplified" options to MF prototype building in OS 3.3

## Version 0.4.0
* Updated OS Extension dependency to 0.5.1
* Updated OS Standards dependency to 0.2.15
* adding compatibility matrix and contribution policy

## Version 0.3.2
* Modify HPWH measure "simplified" option to automatically identify water heater objects without explicit user naming
* Modify HPWH measure to improve integration with URBANopt workflow
* Update HPWH measure documentation

## Version 0.3.1
* Updated OS Extension dependency to 0.4.2
* Updated OS Standards dependency to 0.2.13
* Added Jenkins file for CI testing

## Version 0.3.0
* Merged [#20](https://github.com/NREL/openstudio-load-flexibility-measures-gem/pull/20), 030 upgrade
  * Added Ruby 2.7.0 dependency
  * Updated OS Extension dependency to 0.4.0
* Updated documentation for Add Packaged Ice Storage measure
* Corrected output variable in Add HPWH measure

## Version 0.2.1
* Updated dependency for OS Extension 0.3.2
* Removed extraneous delimiter argument from Add Packaged Ice Storage measure
  * Fixed [#18](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/18), remove "delimiter" argument from add_packaged_ice_storage

## Version 0.2.0

* Updated dependencies for OS Version 3.1:
  * Merged [#15](https://github.com/NREL/openstudio-load-flexibility-measures-gem/pull/15), Os 3.1.0
  * OS Extension set to 0.3.1
  * OS Standards set to 0.2.12
* Updated measure names within documentation
* Updated documentation for Add Packaged Ice Storage measure

## Version 0.1.3

* Measures have been renamed and readme updated:
  * "Add Ice Storage to Plant Loop for Load Flexibility" is now "Add Central Ice Storage"
  * "Add Distributed Ice Storage to Air Loop for Load Flexibility" is now "Add Packaged Ice Storage"
  * "Add Central HPHW for Load Flexibility" is now "Add HPHW"
* Bug Fixes:
  * [#12](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/12), File names become too long when using with URBANopt CLI

## Version 0.1.2

* Bug Fixes:
  * [#4](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/4), use unix paths in 'add_distributed_ice_storage_to_air_loop_for_load_flexibility'
  * [#6](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/6), code error in add_distributed measure
  * [#8](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/8), EMS output variables cause measure failure
* Remove .DS_Store and exclude from future releases
* Code cleanup

## Version 0.1.1

* Initial release
