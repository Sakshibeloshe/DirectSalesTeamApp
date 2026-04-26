require 'xcodeproj'

project_path = './DirectSalesTeamApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add GRDB package
pkg = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg.repositoryURL = "https://github.com/groue/GRDB.swift.git"
pkg.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "6.0.0" }
project.root_object.package_references << pkg

frameworks_phase = target.frameworks_build_phase

product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product_dep.package = pkg
product_dep.product_name = "GRDB"

build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product_dep
frameworks_phase.files << build_file

project.save
puts "Added GRDB to project"
