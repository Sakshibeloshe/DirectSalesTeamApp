require 'xcodeproj'

project_path = '/Users/chirag/Projects/LMS/DirectSalesTeamApp/DirectSalesTeamApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings.delete('SWIFT_DEFAULT_ACTOR_ISOLATION')
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = "minimal"
end

project.save
puts "Removed SWIFT_DEFAULT_ACTOR_ISOLATION"
