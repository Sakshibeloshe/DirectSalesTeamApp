require 'xcodeproj'
require 'fileutils'

project_path = '/Users/chirag/Projects/LMS/DirectSalesTeamApp/DirectSalesTeamApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

files_to_remove = [
  'DirectSalesTeamApp/Auth/KYCRepository.swift',
  'DirectSalesTeamApp/Auth/KYCViewModel.swift'
]

# Delete from disk
files_to_remove.each do |file|
  path = File.join('/Users/chirag/Projects/LMS/DirectSalesTeamApp', file)
  FileUtils.rm_f(path)
  puts "Deleted file: #{path}"
end

# Delete from Xcode project
project.files.each do |file_ref|
  if files_to_remove.any? { |path| file_ref.real_path.to_s.end_with?(path.split('/').last) }
    file_ref.remove_from_project
    puts "Removed reference for: #{file_ref.path}"
  end
end

project.save
puts "Project saved."
