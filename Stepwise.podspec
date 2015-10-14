Pod::Spec.new do |s|
  s.name         = "Stepwise"
  s.version      = "2.1"
  s.summary      = "Serial, cancelable, generic, asynchronous tasks in Swift."
  s.description  = "Stepwise is a framework for creating a series of steps quickly and easily. Every step can take a single input and have a single output, and steps can depend on each other to build chains and pass outputs down the chain."
  s.homepage     = "https://github.com/websdotcom/Stepwise"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Kevin Barrett" => "kevin@webs.com" }
  s.source       = { :git => "https://github.com/websdotcom/Stepwise.git", :tag => s.version }
  s.source_files  = "Stepwise.swift"
  s.ios.deployment_target = "8.0"
end
