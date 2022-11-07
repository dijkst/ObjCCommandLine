
Pod::Spec.new do |spec|

  spec.name         = "ObjCCommandLine"
  spec.version      = "0.0.6"
  spec.summary      = "Command Line Wrapper."

  spec.description  = <<-DESC
  	Commandline Wrapper, it provides some motheds to call the progress.
                   DESC

  spec.homepage     = "https://github.com/dijkst/ObjCCommandLine.git"

  spec.license      = "MIT"
  spec.platform     = :osx, '10.15'
  spec.author       = { "Whirlwind James" => "whirlwindjames@foxmail.com" }

  spec.source       = { :git => "https://github.com/dijkst/ObjCCommandLine.git", :tag => "v#{spec.version}" }

  spec.source_files = "ObjCCommandLine", "ObjCCommandLine/**/*.{h,m}"

  spec.frameworks   = "Foundation"
end
