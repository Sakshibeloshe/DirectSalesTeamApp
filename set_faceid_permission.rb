require 'xcodeproj'

project_path = '/Users/chirag/Projects/LMS/DirectSalesTeamApp/DirectSalesTeamApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_NSFaceIDUsageDescription'] = "We need Face ID to authenticate you securely."
end

project.save
puts "Info.plist build setting updated"
