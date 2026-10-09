platform :ios, '14.0'

target 'Gaibreanno' do
  use_modular_headers!
  pod 'Alamofire', '~> 5.10'
  # Firebase 11 preserves the project's iOS 14 deployment target.
  pod 'FirebaseCore', '~> 11.0'
  pod 'FirebaseMessaging', '~> 11.0'
end

# Declare CocoaPods' temporary resource list while keeping Xcode script sandboxing enabled.
post_integrate do |installer|
  installer.aggregate_targets.map(&:user_project).uniq.each do |project|
    project.native_targets.each do |target|
      target.shell_script_build_phases.each do |phase|
        next unless phase.name == '[CP] Copy Pods Resources'
        output = '${PODS_ROOT}/resources-to-copy-${TARGETNAME}.txt'
        phase.output_paths = (Array(phase.output_paths) + [output]).uniq
      end
    end
    project.save
  end
end
