require 'xcodeproj'
project = Xcodeproj::Project.open('./DirectSalesTeamApp.xcodeproj')
target = project.targets.first

def add_files_to_group(project, target, group, path)
  Dir.glob(File.join(path, '*')).each do |file_path|
    if File.directory?(file_path)
      folder_name = File.basename(file_path)
      sub_group = group.groups.find { |g| g.display_name == folder_name || g.path == folder_name }
      sub_group ||= group.new_group(folder_name, folder_name)
      add_files_to_group(project, target, sub_group, file_path)
    elsif File.extname(file_path) == '.swift'
      file_name = File.basename(file_path)
      unless group.files.any? { |f| f.path == file_name || f.path == file_path }
        file_ref = group.new_file(file_name)
        target.source_build_phase.add_file_reference(file_ref)
        puts "Added #{file_name}"
      end
    end
  end
end

generated_group = project.main_group.find_subpath(File.join('DirectSalesTeamApp', 'Networking', 'Generated'), true)
add_files_to_group(project, target, generated_group, 'DirectSalesTeamApp/Networking/Generated')

project.save
