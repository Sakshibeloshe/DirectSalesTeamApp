require 'xcodeproj'

project_path = '/Users/chirag/Projects/LMS/DirectSalesTeamApp/DirectSalesTeamApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add Swift Package dependencies
project.root_object.package_references.clear

# grpc-swift-2
pkg1 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg1.repositoryURL = "https://github.com/grpc/grpc-swift-2.git"
pkg1.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "2.3.0" }
project.root_object.package_references << pkg1

# grpc-swift-nio-transport
pkg2 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg2.repositoryURL = "https://github.com/grpc/grpc-swift-nio-transport.git"
pkg2.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "2.6.2" }
project.root_object.package_references << pkg2

# grpc-swift-protobuf
pkg3 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg3.repositoryURL = "https://github.com/grpc/grpc-swift-protobuf.git"
pkg3.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "2.2.1" }
project.root_object.package_references << pkg3

# We also need SwiftProtobuf
pkg4 = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
pkg4.repositoryURL = "https://github.com/apple/swift-protobuf.git"
pkg4.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "1.25.0" }
project.root_object.package_references << pkg4

# Add products to frameworks build phase
frameworks_phase = target.frameworks_build_phase

# Function to add package product dependency
def add_package_product(project, target, frameworks_phase, package_ref, product_name)
  product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dep.package = package_ref
  product_dep.product_name = product_name
  
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dep
  frameworks_phase.files << build_file
end

add_package_product(project, target, frameworks_phase, pkg1, "GRPCCore")
add_package_product(project, target, frameworks_phase, pkg1, "GRPCCodeGen")
add_package_product(project, target, frameworks_phase, pkg1, "GRPCInProcessTransport")
add_package_product(project, target, frameworks_phase, pkg2, "GRPCNIOTransportHTTP2")
add_package_product(project, target, frameworks_phase, pkg2, "GRPCNIOTransportHTTP2Posix")
add_package_product(project, target, frameworks_phase, pkg2, "GRPCNIOTransportHTTP2TransportServices")
add_package_product(project, target, frameworks_phase, pkg3, "GRPCProtobuf")
add_package_product(project, target, frameworks_phase, pkg4, "SwiftProtobuf")
add_package_product(project, target, frameworks_phase, pkg4, "SwiftProtobufPluginLibrary")

project.save
puts "Project updated successfully"
