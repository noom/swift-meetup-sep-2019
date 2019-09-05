# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'
use_frameworks!

def shared
  pod 'RxSwift', '~> 5'
  pod 'RxCocoa', '~> 5'
  pod 'RxFeedback', '~> 3.0'
  pod 'RxDataSources', '~> 4.0'
  pod 'SwiftyJSON', '~> 5.0'
  pod 'SwiftDate', '~> 6.0'
  pod 'SnapKit', '~> 5.0'
end

target 'NoomStateMachines' do
  shared
end

target 'NoomStateMachinesTests' do
  shared
  pod 'RxTest', '~> 5'
end
